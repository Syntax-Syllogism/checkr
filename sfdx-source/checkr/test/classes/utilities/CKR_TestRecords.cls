/**
 * Builds in-memory SObjects for unit tests without touching the database.
 * Supports formula and read-only fields and parent relationships, which the
 * SObject constructor cannot set.
 */
@IsTest
public class CKR_TestRecords {
  /**
   * Returns a syntactically valid fake Id for the SObject type.
   *
   * @param sObjectType type whose key prefix is used
   * @param sequence unique number within the test
   * @return fake record id
   */
  public static Id fakeId(SObjectType sObjectType, Integer sequence) {
    String prefix =
      sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix();
    String body = String.valueOf(sequence).leftPad(12, '0');
    return (Id) (prefix + body);
  }

  /**
   * Builds an SObject through JSON deserialization.
   *
   * @param sObjectType type to build
   * @param fields field values keyed by API name; a dotted key such as
   * CKR_ChecklistTemplate__r.Name populates a parent relationship
   * @return the record, typed as the concrete SObject
   */
  public static SObject build(
    SObjectType sObjectType,
    Map<String, Object> fields
  ) {
    Map<String, Object> payload = buildPayload(sObjectType, fields);
    String typeName =
      sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getName();
    try {
      return (SObject) JSON.deserialize(
        JSON.serialize(payload),
        Type.forName(typeName)
      );
    } catch (JSONException ex) {
      throw new CKR_TestRecordsException(
        'Could not build ' + typeName + ': ' + ex.getMessage()
      );
    }
  }

  private static Map<String, Object> buildPayload(
    SObjectType sObjectType,
    Map<String, Object> fields
  ) {
    Map<String, Object> payload =
      new Map<String, Object>{
        'attributes' => new Map<String, Object>{
          'type' => sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
            .getName()
        }
      };
    Map<String, Map<String, Object>> relationshipFields =
      new Map<String, Map<String, Object>>();
    for (String key : fields.keySet()) {
      if (key.contains('.')) {
        String relationshipName = key.substringBefore('.');
        if (!relationshipFields.containsKey(relationshipName)) {
          relationshipFields.put(relationshipName, new Map<String, Object>());
        }
        relationshipFields.get(relationshipName)
          .put(key.substringAfter('.'), fields.get(key));
      } else {
        if (
          !sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
            .fields
            .getMap()
            .containsKey(key)
        ) {
          throw new CKR_TestRecordsException(
            'Unknown field '
            + key
            + ' on '
            + sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getName()
          );
        }
        payload.put(key, fields.get(key));
      }
    }
    for (String relationshipName : relationshipFields.keySet()) {
      SObjectType parentType = parentType(sObjectType, relationshipName);
      payload.put(
        relationshipName,
        buildPayload(parentType, relationshipFields.get(relationshipName))
      );
    }
    return payload;
  }

  private static SObjectType parentType(
    SObjectType sObjectType,
    String relationshipName
  ) {
    if (relationshipName == 'Owner') {
      return User.SObjectType;
    }
    String lookupName =
      relationshipName.endsWith('__r')
      ? relationshipName.removeEnd('__r') + '__c'
      : relationshipName + 'Id';
    SObjectField lookup =
      sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .fields
        .getMap()
        .get(lookupName);
    if (lookup == null) {
      throw new CKR_TestRecordsException(
        'Unknown relationship '
        + relationshipName
        + ' on '
        + sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getName()
      );
    }
    return lookup.getDescribe()
    .getReferenceTo()[0];
  }

  /**
   * Represents errors raised while building test records.
   */
  public class CKR_TestRecordsException extends Exception {
  }
}
