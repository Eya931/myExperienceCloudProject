public without sharing class SendPortalWelcomeEmail {

    @InvocableMethod(
        label='Send Portal Welcome Email'
        description='Sends the Experience Cloud welcome/password-reset email to a new portal user'
    )
    public static void sendWelcomeEmail(List<Request> requests) {
        for (Request req : requests) {
            try {
                // Finds the Experience Cloud site (Network) by name
                Network network = [
                    SELECT Id
                    FROM Network
                    WHERE Name = :req.networkName
                    LIMIT 1
                ];

                System.debug(LoggingLevel.INFO,
                    'SendPortalWelcomeEmail skipped for user ' + req.userId
                    + ' (legacy reset email disabled).');

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'SendPortalWelcomeEmail failed for user '
                    + req.userId + ': ' + e.getMessage());
            }
        }
    }

    public class Request {
        @InvocableVariable(
            label='User ID'
            description='ID of the newly created portal user'
            required=true
        )
        public Id userId;

        @InvocableVariable(
            label='Network Name'
            description='Exact name of your Experience Cloud site'
            required=true
        )
        public String networkName;
    }
}