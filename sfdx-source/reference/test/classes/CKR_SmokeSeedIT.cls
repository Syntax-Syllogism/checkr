@IsTest
private class CKR_SmokeSeedIT {
  private static final String ACCOUNT_PREFIX = 'Checkr Smoke - ';

  @IsTest
  static void userSeedThenDataSeed_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      provisionSmokePersonas();
      CheckrSmokeUserSeed.run();
    }

    Test.startTest();
    CheckrSmokeSeed.run();
    Test.stopTest();

    Id adminUserId = UserInfo.getUserId();
    System.Assert.isTrue(
        [
          SELECT COUNT()
          FROM Account
          WHERE Name LIKE :(ACCOUNT_PREFIX + '%') AND OwnerId = :adminUserId
        ]
        > 0,
        'The data seed creates smoke Accounts owned by the admin persona.'
      );
    System.Assert.isTrue(
        [
          SELECT COUNT()
          FROM CKR_ChecklistTemplateVersion__c
          WHERE CKR_Status__c = 'Published'
        ]
        > 0,
        'The data seed publishes template versions.'
      );
    System.Assert.isTrue(
        [SELECT COUNT() FROM CKR_ChecklistInstance__c] > 0,
        'The data seed attaches checklist instances.'
      );
    System.Assert.isTrue(
        [SELECT COUNT() FROM AccountShare WHERE RowCause = 'Manual'] > 0,
        'The data seed shares smoke Accounts with the persona users.'
      );
    System.Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM PermissionSetAssignment
          WHERE AssigneeId = :adminUserId AND PermissionSet.Name = 'CKR_Admin'
        ],
        'The user seed assigns CKR_Admin to the admin persona.'
      );
  }

  @IsTest
  static void userSeedCreatesMissingPersonasAndReassignsPermissions_integrationHappyPath() {
    Map<String, String> usernames = CheckrSmokeUserSeed.usernamesByPersona();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      // Reuse the admin license; let the seed create the Platform personas.
      update new User(
        Id = UserInfo.getUserId(),
        Username = usernames.get(CheckrSmokeUserSeed.PERSONA_ADMIN)
      );
      CheckrSmokeUserSeed.run();
      CheckrSmokeUserSeed.run();
    }

    List<User> personas = [
      SELECT Id, Username, Alias
      FROM User
      WHERE Username IN :usernames.values()
    ];
    System.Assert.areEqual(
        4,
        personas.size(),
        'Rerunning the seed must reuse all four personas.'
      );
    Set<Id> personaIds = new Map<Id, User>(personas).keySet();
    Map<Id, Set<String>> permissionsByUser = new Map<Id, Set<String>>();
    for (PermissionSetAssignment assignment : [
      SELECT AssigneeId, PermissionSet.Name
      FROM PermissionSetAssignment
      WHERE AssigneeId IN :personaIds AND PermissionSet.IsOwnedByProfile = false
    ]) {
      if (!permissionsByUser.containsKey(assignment.AssigneeId)) {
        permissionsByUser.put(assignment.AssigneeId, new Set<String>());
      }
      permissionsByUser.get(assignment.AssigneeId)
        .add(assignment.PermissionSet.Name);
    }
    Map<String, Set<String>> expectedByUsername =
      new Map<String, Set<String>>{
        usernames.get(CheckrSmokeUserSeed.PERSONA_ADMIN) => new Set<String>{
          'CKR_Admin'
        },
        usernames.get(CheckrSmokeUserSeed.PERSONA_READ_ONLY) => new Set<String>{
          'CKR_ReadOnly'
        },
        usernames.get(CheckrSmokeUserSeed.PERSONA_COMPLETER) => new Set<String>{
          'CKR_User'
        },
        usernames.get(
          CheckrSmokeUserSeed.PERSONA_COMPLIANCE
        ) => new Set<String>{ 'CKR_User', 'CKR_Smoke_Compliance' }
      };
    for (User persona : personas) {
      System.Assert.areEqual(
          expectedByUsername.get(persona.Username),
          permissionsByUser.get(persona.Id),
          'Repeated seeds must restore only the intended persona permissions.'
        );
      if (persona.Id != UserInfo.getUserId()) {
        System.Assert.isTrue(
            persona.Alias.startsWith('ckr'),
            'Created personas have smoke aliases.'
          );
      }
    }
  }

  @IsTest
  static void dataSeedWithoutSmokeUsersFailsClearly() {
    Map<String, String> usernames = CheckrSmokeUserSeed.usernamesByPersona();
    System.Assert.areEqual(
        0,
        [SELECT COUNT() FROM User WHERE Username IN :usernames.values()],
        'This test needs an org where the smoke user seed has not been run.'
      );
    try {
      CheckrSmokeSeed.run();
      System.Assert.fail('The data seed requires the smoke users.');
    } catch (CheckrSmokeSeed.SeedException error) {
      System.Assert.isTrue(
          error.getMessage().contains('Run CheckrSmokeUserSeed.run() first.'),
          'The error names the missing seed step: ' + error.getMessage()
        );
    }
  }

  // Evidence orgs often have no spare Salesforce license, so the running admin
  // takes the admin persona's username (rolled back with the test) and the
  // other personas use Salesforce Platform licenses.
  private static void provisionSmokePersonas() {
    Map<String, String> usernames = CheckrSmokeUserSeed.usernamesByPersona();
    update new User(
      Id = UserInfo.getUserId(),
      Username = usernames.get(CheckrSmokeUserSeed.PERSONA_ADMIN)
    );
    Id platformProfileId =
      [
        SELECT Id
        FROM Profile
        WHERE UserLicense.Name = 'Salesforce Platform'
        ORDER BY Name
        LIMIT 1
      ]
        .Id;
    List<User> personas = new List<User>();
    for (String persona : usernames.keySet()) {
      if (persona == CheckrSmokeUserSeed.PERSONA_ADMIN) {
        continue;
      }
      String username = usernames.get(persona);
      personas.add(
        new User(
          Username = username,
          LastName = 'Checkr Smoke IT ' + persona,
          Email = username,
          Alias = 'ckrit' + personas.size(),
          TimeZoneSidKey = 'America/New_York',
          LocaleSidKey = 'en_US',
          EmailEncodingKey = 'UTF-8',
          LanguageLocaleKey = 'en_US',
          ProfileId = platformProfileId
        )
      );
    }
    insert personas;
  }
}
