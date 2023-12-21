public with sharing class ContactUsSearchController {
    @AuraEnabled(cacheable=true)
    public static SearchData getAccountsByAbaNumber(String abaNumber) {
    SearchData searchContactUsContact = new SearchData();
    List<Account> accountList = new List<Account>();

    accountList= 
    [
        SELECT id,Name,ABA__c 
        FROM Account
        WHERE ABA__c =: abaNumber WITH SECURITY_ENFORCED
    ];
    System.debug('@@@@ accountList +'+ accountList );
    if(accountList.size() > 0){
        searchContactUsContact.accountName = accountList[0].Name;
        searchContactUsContact.status = 'success';
        searchContactUsContact.message = 'ContactUsContact Available';
    }
    else{
        searchContactUsContact.status = 'error';
        searchContactUsContact.message = 'Please Specify a valid ABA Number';
    }
    System.debug('@@@@ searchContactUsContact +'+ searchContactUsContact );
    return searchContactUsContact;
    }
    public class SearchData {
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public String message {get;set;}
        @AuraEnabled public String accountName {get;set;}
    }
}