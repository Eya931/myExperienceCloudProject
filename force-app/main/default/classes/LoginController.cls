public without sharing class LoginController {
    @AuraEnabled
    public static String login(String username, String password, String startUrl) {
        try {
            ApexPages.PageReference pageRef = Site.login(username, password, startUrl);
            if (pageRef != null) {
                return pageRef.getUrl();
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Login failed: ' + e.getMessage());
        }
    }
}
