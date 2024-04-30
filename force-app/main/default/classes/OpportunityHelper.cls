public with sharing class OpportunityHelper {
        /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    public static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Set<Id> userIds = new Set<Id>();

        for (Opportunity oppDeleted : opps) {
            userIds.add(oppDeleted.OwnerId);
        }

        Map<Id,User> userMap = new Map<Id,User>([SELECT Id, Email FROM User WHERE Id IN :userIds]);

        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>();
            toAddresses.add(UserMap.get(opp.OwnerId).Email);
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    public static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {

        Set<Id> accIds = new Set<Id>();
        for (Opportunity opp : oppNewMap.values()) {
            accIds.add(opp.AccountId);
        }

        List<Contact> primaryContacts = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Title = 'VP Sales' AND AccountId
            IN :accIds
            ];
        Map<Id,Contact> accIdContactMap = new Map<Id,Contact>();
        for (Contact cont : primaryContacts) {
            accIdContactMap.put(cont.AccountId, cont);
        }
        
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : oppNewMap.values()){            
            if (opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = accIdContactMap.get(opp.AccountId).Id;
                oppsToUpdate.add(oppToUpdate);
            }
        }
        update oppsToUpdate;
    }
}