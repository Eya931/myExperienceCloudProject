public without sharing class RegisterController {
    @AuraEnabled
    public static String registerUser(
        String firstName,
        String lastName,
        String email,
        String password,
        String confirmPassword,
        String startUrl
    ) {
        if (password != confirmPassword) {
            throw new AuraHandledException('Passwords do not match.');
        }

        try {
            // 1) Find or create a default Account for Job Seekers
            String accountName = 'Job Seekers';
            List<Account> accts = [
                SELECT Id FROM Account WHERE Name = :accountName LIMIT 1
            ];
            Account acct;
            if (accts.isEmpty()) {
                acct = new Account(Name = accountName);
                insert acct;
            } else {
                acct = accts[0];
            }

            // 2) Create the external user – Site.createExternalUser
            //    automatically creates a Contact under the given Account
            String nickname = firstName + '.' + lastName + '.' +
                String.valueOf(Math.round(Math.random() * 10000));

            User u = new User(
                FirstName          = firstName,
                LastName           = lastName,
                Email              = email,
                Username           = email,
                CommunityNickname  = nickname,
                Alias              = firstName.left(4) + lastName.left(4)
            );

            String userId = Site.createExternalUser(u, acct.Id, password);

            if (String.isNotBlank(userId)) {
                ApexPages.PageReference pageRef = Site.login(email, password, startUrl);
                if (pageRef != null) {
                    return pageRef.getUrl();
                }
            }
            return null;
        } catch (Site.ExternalUserCreateException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Registration failed: ' + e.getMessage());
        }
    }
}