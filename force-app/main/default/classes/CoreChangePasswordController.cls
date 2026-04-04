/* * CoreChangePasswordController
 * Thin @AuraEnabled wrapper around the native Salesforce
 * ChangePasswordController so our LWC component can call it.
 *
 * We cannot call ChangePasswordController directly from LWC because:
 * - Its changePassword() method is not @AuraEnabled
 * - It uses instance properties (oldPassword, newPassword, verifyNewPassword)
 *   instead of method parameters
 *
 * Solution: delegate to Site.changePassword() directly —
 * exactly what the native class does internally.
 */
public without sharing class CoreChangePasswordController {
    @AuraEnabled
    public static void changePassword(String newPassword, String confirmPassword, String token) {
        try {
            if (newPassword != confirmPassword) {
                throw new AuraHandledException('Les mots de passe ne correspondent pas.');
            }

            // Trouve le user via le token
            List<User> users = [
                SELECT Id 
                FROM User 
                WHERE Reset_Token__c = :token
                AND IsActive = true  
                LIMIT 1
            ];

            if (users.isEmpty()) {
                throw new AuraHandledException('Token invalide ou expiré.');
            }

            System.setPassword(users[0].Id, newPassword);
            // Efface le token après usage
            update new User(Id = users[0].Id, Reset_Token__c = null);

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}