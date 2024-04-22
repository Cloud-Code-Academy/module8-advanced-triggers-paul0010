public with sharing class OpportunityTriggerHandler extends TriggerHandler{

    private List<Opportunity> newOppList;
    private List<Opportunity> oldOppList;
    private Map<Id, Opportunity> newOppMap;
    private Map<Id, Opportunity> oldOppMap;

    public OpportunityTriggerHandler() {
        this.newOppList = (List<Opportunity>) Trigger.new;
        this.oldOppList = (List<Opportunity>) Trigger.old;
        this.newOppMap = (Map<Id, Opportunity>) Trigger.newMap;
        this.oldOppMap = (Map<Id, Opportunity>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        // Set default Type for new Opportunities
        for (Opportunity opp : this.newOppList) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }
        }
    }

    public override void beforeUpdate() {
        //When an opportunity is updated validate that the amount is greater than 5000.
        for(Opportunity opp : this.newOppList){
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
        //When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
        //Get contacts related to the opportunity account
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : this.newOppList){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([
            SELECT Id, FirstName, AccountId
            FROM Contact
            WHERE AccountId
            IN :accountIds AND Title = 'CEO'
            ORDER BY FirstName ASC
            ]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for(Opportunity opp : this.newOppList){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }

    public override void beforeDelete() {
        //When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
        //Account related to the opportunities 
        Map<Id, Account> accounts = new Map<Id, Account>([
            SELECT Id, Industry
            FROM Account
            WHERE Id
            IN (SELECT AccountId FROM Opportunity WHERE Id IN :this.oldOppList)]);
        for(Opportunity opp : this.oldOppList){
            if(opp.IsClosed){
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    public override void afterInsert() {
        // Create a new Task for newly inserted Opportunities
        List<Task> tsks = new List<Task>();
        for (Opportunity opp : this.newOppList){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            tsks.add(tsk);
        }
        insert tsks;
    }
    public override void afterUpdate() {
        // Append Stage changes in Opportunity Description
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : this.newOppList){
                if (opp.StageName != null && opp.StageName != this.oldOppMap.get(opp.Id).StageName){
                    Opportunity newOpp = new Opportunity(Id = opp.Id);
                    newOpp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                    oppsToUpdate.add(newOpp);
                }              
        }
        update oppsToUpdate;
    }

    public override void afterDelete() {
        // Send email notifications when an Opportunity is deleted 
        OpportunityHelper.notifyOwnersOpportunityDeleted(this.oldOppList);
    }

    public override void afterUndelete() {
        // Assign the primary contact to undeleted Opportunities
        OpportunityHelper.assignPrimaryContact(this.newOppMap);
    }
}