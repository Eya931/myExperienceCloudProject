public without sharing class CreatePortalUserAndNotify {

    @InvocableMethod(
        label='Create Portal User Without Auto Email'
    )
    public static List<Result> createUser(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();
            try {
                if (req.contactId == null) {
                    throw new AuraHandledException('ContactId is required.');
                }

                List<User> existingUsers = [
                    SELECT Id, IsActive, ContactId
                    FROM User
                    WHERE ContactId = :req.contactId
                    LIMIT 1
                ];

                if (!existingUsers.isEmpty()) {
                    User existing = existingUsers[0];
                    if (!existing.IsActive) {
                    // ✅ Réactive le user existant au lieu d'en créer un nouveau
                    existing.IsActive   = true;
                    existing.ContactId  = req.contactId;
                    existing.ProfileId  = req.profileId;
                    update existing;
                    
                    res.userId  = existing.Id;
                    res.success = true;
                    
                    // Envoie le reset password au user réactivé
                    System.enqueueJob(new SendResetPasswordEmailQueueable(existing.Id));
                    }else{
                        // User actif existant → juste renvoyer l'email
                        res.userId = existing.Id;
                        res.success = true;
                        System.enqueueJob(new SendResetPasswordEmailQueueable(existing.Id));
                    }
                    logOutcomeOnOpportunity(req, res);
                    results.add(res);
                    continue;
                }

                String safeFirstName = String.isNotBlank(req.firstName) ? req.firstName : 'Candidate';
                String safeLastName  = String.isNotBlank(req.lastName) ? req.lastName : 'Portal';

                // ── 1. Créer l'utilisateur ─────────────────────────
                User u = new User();
                u.Alias             = safeFirstName.length() > 8
                                      ? safeFirstName.substring(0, 8)
                                      : safeFirstName;
                u.ContactId         = req.contactId;
                u.Email             = req.email;
                u.EmailEncodingKey  = 'UTF-8';
                u.FirstName         = safeFirstName;
                u.LastName          = safeLastName;
                u.LanguageLocaleKey = 'fr';
                u.LocaleSidKey      = 'fr_FR';
                u.ProfileId         = req.profileId;
                u.TimeZoneSidKey    = 'Africa/Tunis';
                u.Username          = req.username;
                u.IsActive          = true;

                Database.DMLOptions dlo = new Database.DMLOptions();
                dlo.EmailHeader.triggerAutoResponseEmail = false;
                dlo.EmailHeader.triggerOtherEmail        = false;
                dlo.EmailHeader.triggerUserEmail         = false;
                Database.insert(u, dlo);

                // ── 2. Reset password dans un Queueable séparé ────
                // Évite le Mixed DML entre User insert et resetPassword
                System.enqueueJob(new SendResetPasswordEmailQueueable(u.Id));//, req.email, req.firstName));

                res.userId  = u.Id;
                res.success = true;

            } catch (Exception e) {
                res.success      = false;
                res.errorMessage = 'Contact ' + String.valueOf(req.contactId) + ': ' + e.getMessage();
                System.debug(LoggingLevel.ERROR,
                    'CreatePortalUserAndNotify error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            }
            logOutcomeOnOpportunity(req, res);
            results.add(res);
        }
        return results;
    }

    private static void logOutcomeOnOpportunity(Request req, Result res) {
        if (req == null || req.opportunityId == null || res == null) {
            return;
        }

        try {
            Opportunity opp = [
                SELECT Id, Description
                FROM Opportunity
                WHERE Id = :req.opportunityId
                LIMIT 1
            ];

            String timestamp = Datetime.now().format('yyyy-MM-dd HH:mm:ss', 'GMT');
            String status = res.success ? 'SUCCESS' : 'ERROR';
            String details = res.success
                ? ('UserId=' + String.valueOf(res.userId) + ', ContactId=' + String.valueOf(req.contactId))
                : ('ContactId=' + String.valueOf(req.contactId) + ', Error=' + String.valueOf(res.errorMessage));

            String line = '[PortalUserFlow][' + timestamp + ' GMT][' + status + '] ' + details;
            String existing = opp.Description;
            String merged = String.isBlank(existing) ? line : (existing + '\n' + line);

            if (merged.length() > 32000) {
                merged = merged.substring(merged.length() - 32000);
            }

            opp.Description = merged;
            update opp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'CreatePortalUserAndNotify monitoring log failed: ' + e.getMessage());
        }
    }

    public class Request {
        @InvocableVariable(label='Contact ID'  required=true) public Id     contactId;
        @InvocableVariable(label='Email'       required=true) public String email;
        @InvocableVariable(label='First Name'  required=true) public String firstName;
        @InvocableVariable(label='Last Name'   required=true) public String lastName;
        @InvocableVariable(label='Username'    required=true) public String username;
        @InvocableVariable(label='Profile ID'  required=true) public Id     profileId;
        @InvocableVariable(label='Opportunity ID')            public Id     opportunityId;
    }

    public class Result {
        @InvocableVariable(label='User ID')       public Id      userId;
        @InvocableVariable(label='Success')       public Boolean success;
        @InvocableVariable(label='Error Message') public String  errorMessage;
    }
}