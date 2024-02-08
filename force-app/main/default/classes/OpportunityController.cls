public with sharing class OpportunityController {
    @AuraEnabled(cacheable=true)
    public static List<OpportunityWrapper> getOpportunityDetails(String opportunityId) {
        List<OpportunityWrapper> result = new List<OpportunityWrapper>();

        // Retrieve Opportunity details along with related objects
        Opportunity opp = [SELECT Id, Name, Amount, CloseDate, Account.Name,
                          (SELECT Product2.Name, Quantity, TotalPrice FROM OpportunityLineItems)
                          FROM Opportunity WHERE Id = :opportunityId];

        // Extract data for LWC
        OpportunityWrapper oppWrapper = new OpportunityWrapper();
        oppWrapper.opportunityName = opp.Name;
        oppWrapper.opportunityAmount = opp.Amount;
        oppWrapper.opportunityCloseDate = opp.CloseDate;
        oppWrapper.accountName = opp.Account.Name;

        for (OpportunityLineItem oli : opp.OpportunityLineItems) {
            oppWrapper.products.add(new ProductWrapper(oli.Product2.Name, oli.Quantity, oli.TotalPrice));
        }

        result.add(oppWrapper);

        return result;
    }

    // Wrapper class for Opportunity data
    public class OpportunityWrapper {
        @AuraEnabled
        public String opportunityName;

        @AuraEnabled
        public Decimal opportunityAmount;

        @AuraEnabled
        public Date opportunityCloseDate;

        @AuraEnabled
        public String accountName;

        @AuraEnabled
        public List<ProductWrapper> products;

        public OpportunityWrapper() {
            products = new List<ProductWrapper>();
        }
    }

    // Wrapper class for Product data
    public class ProductWrapper {
        @AuraEnabled
        public String productName;

        @AuraEnabled
        public Decimal quantity;

        @AuraEnabled
        public Decimal amount;

        public ProductWrapper(String name, Decimal qty, Decimal amt) {
            productName = name;
            quantity = qty;
            amount = amt;
        }
    }
}