public inherited sharing class CheckrSmokeUserSeed {
  public class SeedException extends Exception {
  }

  public static final String PERSONA_ADMIN = 'admin';
  public static final String PERSONA_READ_ONLY = 'readOnly';
  public static final String PERSONA_COMPLETER = 'completer';
  public static final String PERSONA_COMPLIANCE = 'compliance';

  private static final String USERNAME_DOMAIN = 'example.invalid';
  private static final String LAST_NAME_PREFIX = 'Checkr Smoke';

  public static void run() {
    Map<String, String> usernamesByPersona = usernamesByPersona();
    Map<String, User> existingUsersByUsername =
      selectUsersByUsername(usernamesByPersona.values());
    Id salesforceProfileId = selectProfileIdByLicense('Salesforce');
    Id salesforcePlatformProfileId =
      selectProfileIdByLicense('Salesforce Platform');

    List<User> usersToInsert = new List<User>();
    for (String persona : usernamesByPersona.keySet()) {
      String username = usernamesByPersona.get(persona);
      if (existingUsersByUsername.containsKey(username)) {
        continue;
      }

      Id profileId =
        persona == PERSONA_ADMIN
        ? salesforceProfileId
        : salesforcePlatformProfileId;
      usersToInsert.add(buildUser(persona, username, profileId));
    }

    if (!usersToInsert.isEmpty()) {
      insert usersToInsert;
    }

    Map<String, User> usersByUsername =
      selectUsersByUsername(usernamesByPersona.values());
    Map<String, Id> userIdsByPersona = new Map<String, Id>();
    for (String persona : usernamesByPersona.keySet()) {
      String username = usernamesByPersona.get(persona);
      if (!usersByUsername.containsKey(username)) {
        throw new SeedException(
          'Failed to create or locate smoke user: ' + username
        );
      }
      userIdsByPersona.put(persona, usersByUsername.get(username).Id);
    }

    resetPermissionAssignments(userIdsByPersona.values());
    assignSmokePermissionSets(userIdsByPersona);
    System.debug(buildSummary(userIdsByPersona.size()));
  }

  public static Map<String, String> usernamesByPersona() {
    String orgToken = UserInfo.getOrganizationId().right(8).toLowerCase();
    Map<String, String> usernames = new Map<String, String>();
    usernames.put(
      PERSONA_ADMIN,
      'checkr.smoke.admin.' + orgToken + '@' + USERNAME_DOMAIN
    );
    usernames.put(
      PERSONA_READ_ONLY,
      'checkr.smoke.readonly.' + orgToken + '@' + USERNAME_DOMAIN
    );
    usernames.put(
      PERSONA_COMPLETER,
      'checkr.smoke.completer.' + orgToken + '@' + USERNAME_DOMAIN
    );
    usernames.put(
      PERSONA_COMPLIANCE,
      'checkr.smoke.compliance.' + orgToken + '@' + USERNAME_DOMAIN
    );
    return usernames;
  }

  private static User buildUser(String persona, String username, Id profileId) {
    return new User(
      Username = username,
      LastName = LAST_NAME_PREFIX + ' ' + persona,
      Email = username,
      Alias = aliasForPersona(persona),
      TimeZoneSidKey = 'America/New_York',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = profileId
    );
  }

  private static String aliasForPersona(String persona) {
    if (persona == PERSONA_ADMIN) {
      return 'ckradm';
    }
    if (persona == PERSONA_READ_ONLY) {
      return 'ckrrdo';
    }
    if (persona == PERSONA_COMPLETER) {
      return 'ckrcmp';
    }
    return 'ckrcpl';
  }

  private static Id selectProfileIdByLicense(String userLicenseName) {
    List<Profile> profiles = [
      SELECT Id, Name
      FROM Profile
      WHERE UserLicense.Name = :userLicenseName
      ORDER BY Name
      LIMIT 1
    ];
    if (!profiles.isEmpty()) {
      return profiles[0].Id;
    }

    throw new SeedException(
      'No profile found for user license: ' + userLicenseName
    );
  }

  private static Map<String, User> selectUsersByUsername(
    List<String> usernames
  ) {
    Map<String, User> usersByUsername = new Map<String, User>();
    if (usernames == null || usernames.isEmpty()) {
      return usersByUsername;
    }

    for (User userRecord : [
      SELECT Id, Username
      FROM User
      WHERE Username IN :usernames
    ]) {
      usersByUsername.put(userRecord.Username, userRecord);
    }
    return usersByUsername;
  }

  private static void resetPermissionAssignments(List<Id> userIds) {
    if (userIds == null || userIds.isEmpty()) {
      return;
    }

    List<PermissionSetAssignment> assignmentsToDelete = [
      SELECT Id
      FROM PermissionSetAssignment
      WHERE
        AssigneeId IN :userIds
        AND PermissionSet.Name IN (
          'CKR_Admin',
          'CKR_User',
          'CKR_ReadOnly',
          'CKR_Smoke_Compliance'
        )
    ];
    if (!assignmentsToDelete.isEmpty()) {
      delete assignmentsToDelete;
    }
  }

  private static void assignSmokePermissionSets(
    Map<String, Id> userIdsByPersona
  ) {
    Map<String, Id> permissionSetIdsByName = new Map<String, Id>();
    for (PermissionSet permissionSetRecord : [
      SELECT Id, Name
      FROM PermissionSet
      WHERE
        Name IN (
          'CKR_Admin',
          'CKR_User',
          'CKR_ReadOnly',
          'CKR_Smoke_Compliance'
        )
    ]) {
      permissionSetIdsByName.put(
        permissionSetRecord.Name,
        permissionSetRecord.Id
      );
    }

    validatePermissionSet(permissionSetIdsByName, 'CKR_Admin');
    validatePermissionSet(permissionSetIdsByName, 'CKR_User');
    validatePermissionSet(permissionSetIdsByName, 'CKR_ReadOnly');
    validatePermissionSet(permissionSetIdsByName, 'CKR_Smoke_Compliance');

    List<PermissionSetAssignment> assignmentsToInsert =
      new List<PermissionSetAssignment>{
        new PermissionSetAssignment(
          AssigneeId = userIdsByPersona.get(PERSONA_ADMIN),
          PermissionSetId = permissionSetIdsByName.get('CKR_Admin')
        ),
        new PermissionSetAssignment(
          AssigneeId = userIdsByPersona.get(PERSONA_READ_ONLY),
          PermissionSetId = permissionSetIdsByName.get('CKR_ReadOnly')
        ),
        new PermissionSetAssignment(
          AssigneeId = userIdsByPersona.get(PERSONA_COMPLETER),
          PermissionSetId = permissionSetIdsByName.get('CKR_User')
        ),
        new PermissionSetAssignment(
          AssigneeId = userIdsByPersona.get(PERSONA_COMPLIANCE),
          PermissionSetId = permissionSetIdsByName.get('CKR_User')
        ),
        new PermissionSetAssignment(
          AssigneeId = userIdsByPersona.get(PERSONA_COMPLIANCE),
          PermissionSetId = permissionSetIdsByName.get('CKR_Smoke_Compliance')
        )
      };
    insert assignmentsToInsert;
  }

  private static void validatePermissionSet(
    Map<String, Id> permissionSetIdsByName,
    String permissionSetName
  ) {
    if (!permissionSetIdsByName.containsKey(permissionSetName)) {
      throw new SeedException(
        'Missing required smoke permission set: ' + permissionSetName
      );
    }
  }

  private static String buildSummary(Integer smokeUserCount) {
    Integer assignmentCount = [
      SELECT COUNT()
      FROM PermissionSetAssignment
      WHERE
        PermissionSet.Name IN (
          'CKR_Admin',
          'CKR_User',
          'CKR_ReadOnly',
          'CKR_Smoke_Compliance'
        )
    ];

    return 'Checkr smoke users seeded. Users='
      + smokeUserCount
      + ', PermissionAssignments='
      + assignmentCount;
  }
}
