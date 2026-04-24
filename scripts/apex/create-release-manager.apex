// ─── Configure before running ────────────────────────────────────────────────
String USERNAME  = 'release.manager@yourorg.solu'; // must be unique in Salesforce
String EMAIL     = 'devops@yourorg.com';
String TIMEZONE  = 'America/Mexico_City';
String LOCALE    = 'es_MX';
// ─────────────────────────────────────────────────────────────────────────────

List<User> existing = [SELECT Id, Username FROM User WHERE Username = :USERNAME LIMIT 1];

if (!existing.isEmpty()) {
    System.debug('Release Manager already exists — Id: ' + existing[0].Id + ' / ' + USERNAME);
} else {
    Profile p = [
        SELECT Id FROM Profile
        WHERE Name = 'Minimum Access - Salesforce Integration'
        LIMIT 1
    ];

    User u = new User(
        FirstName           = 'Release',
        LastName            = 'Manager',
        Username            = USERNAME,
        Email               = EMAIL,
        Alias               = 'relMgr',
        TimeZoneSidKey      = TIMEZONE,
        LocaleSidKey        = LOCALE,
        EmailEncodingKey    = 'UTF-8',
        LanguageLocaleKey   = 'en_US',
        ProfileId           = p.Id
    );
    insert u;

    PermissionSet ps = [
        SELECT Id FROM PermissionSet
        WHERE Name = 'SOLU_CI_CD_Deployment'
        LIMIT 1
    ];
    insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);

    System.debug('Release Manager created — Id: ' + u.Id + ' / ' + USERNAME);
}
