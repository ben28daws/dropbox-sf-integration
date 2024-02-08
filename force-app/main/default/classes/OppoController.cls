public with sharing class OppoController {
    @AuraEnabled(cacheable=true)
    public static OpportunityWrapper getRecordAndOpportunities(String recordId) {
        Account accountRecord = [SELECT Id, Name FROM Account WHERE Id = :recordId AND CreatedById = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
        List<Opportunity> opportunities = [SELECT Id, Name FROM Opportunity WHERE AccountId = :recordId AND CreatedById = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
        List<String> accountDocumentTitles = extractDocumentTitlesFromAccount(recordId);
        Map<Id, List<String>> opportunityDocumentTitlesMap = extractDocumentTitlesFromOpportunities(opportunities);
        return new OpportunityWrapper(accountRecord, opportunities, accountDocumentTitles, opportunityDocumentTitlesMap);
    }

    public class OpportunityWrapper {
        @AuraEnabled public Account accountRecord;
        @AuraEnabled public List<Opportunity> opportunities;
        @AuraEnabled public List<String> accountDocumentTitles;
        @AuraEnabled public Map<Id, List<String>> opportunityDocumentTitlesMap;

        public OpportunityWrapper(Account accountRecord, List<Opportunity> opportunities, List<String> accountDocumentTitles, Map<Id, List<String>> opportunityDocumentTitlesMap) {
            this.accountRecord = accountRecord;
            this.opportunities = opportunities;
            this.accountDocumentTitles = accountDocumentTitles;
            this.opportunityDocumentTitlesMap = opportunityDocumentTitlesMap;
        }
    }

    public static List<String> extractDocumentTitlesFromAccount(String accountId) {
        List<String> accountDocumentTitles = new List<String>();

        List<ContentDocumentLink> accountContentDocumentLinks = [SELECT ContentDocument.Title
                                                                 FROM ContentDocumentLink
                                                                 WHERE LinkedEntityId = :accountId];

        for (ContentDocumentLink cdl : accountContentDocumentLinks) {
            accountDocumentTitles.add(cdl.ContentDocument.Title);
        }
        return accountDocumentTitles;
    }

    public static Map<Id, List<String>> extractDocumentTitlesFromOpportunities(List<Opportunity> opportunities) {
        Map<Id, List<String>> opportunityDocumentTitlesMap = new Map<Id, List<String>>();

        for (Opportunity opp : opportunities) {
            List<String> opportunityDocumentTitles = new List<String>();

            List<ContentDocumentLink> opportunityContentDocumentLinks = [SELECT ContentDocument.Title
                                                                        FROM ContentDocumentLink
                                                                        WHERE LinkedEntityId = :opp.Id];

            for (ContentDocumentLink cdl : opportunityContentDocumentLinks) {
                opportunityDocumentTitles.add(cdl.ContentDocument.Title);
            }
            opportunityDocumentTitlesMap.put(opp.Id, opportunityDocumentTitles);
        }
        return opportunityDocumentTitlesMap;
    }
}