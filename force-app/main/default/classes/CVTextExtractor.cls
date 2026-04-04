public without sharing class CVTextExtractor {

    // Méthode pour extraire le texte du PDF et le stocker dans le Lead
    /*public static void extractCVText(Id leadId) {
        Lead l = [SELECT Id, CV_File_ID__c, CV_Text__c FROM Lead WHERE Id = :leadId LIMIT 1];

        if (l.CV_File_ID__c != null) {
            // Récupérer le ContentVersion associé
            ContentVersion cv = [SELECT Id, VersionData, Title 
                                 FROM ContentVersion 
                                 WHERE ContentDocumentId = :l.CV_File_ID__c
                                 ORDER BY CreatedDate DESC
                                 LIMIT 1];

            Blob pdfBlob = cv.VersionData;

            // Ici, on simule l'extraction de texte
            // Dans un vrai cas, tu appellerais un parser PDF comme PDFBox / iText
            String extractedText = 'Texte extrait simulé du PDF: ' + cv.Title;

            // Stocker dans le Lead
            l.CV_Text__c = extractedText;
            update l;
        }
    }*/
}