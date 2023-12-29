public with sharing class ContactUsSearchController {
    /**
    * This method is second approach that will be used to populate the ContactUsContactDetails wrapper class for LWC.
    */
    @AuraEnabled(cacheable=true)
    public static SearchData getContactDetails(String abaNumber) {
        SearchData searchContactUsContact = new SearchData();
        try{
            System.debug('ABA number :: '+abaNumber);
            
            List<Account> accountList = new List<Account>();
            
            String seachAba = String.escapeSingleQuotes(abaNumber);
            accountList = [SELECT id,Name,ABA__c 
                            FROM Account
                            WHERE ABA__c =: seachAba WITH SECURITY_ENFORCED];

            System.debug('accountList  :: '+accountList.size());
            if(accountList.size() > 0) {
                List<Category> categoryList = new List<Category>(); 
                Set<Id> ContactUsContactIDSet = new Set<Id>();
                
                String firstFourNumber = seachAba.substring(0,4);
                List<ContactUsContactByABAPrefix__c> ContactUsContactABAPrefixList = new List<ContactUsContactByABAPrefix__c>();
                
                ContactUsContactABAPrefixList= getContactUsContactByABAPrefix(firstFourNumber);
                
                if(ContactUsContactABAPrefixList.size() > 0) {
                    for(ContactUsContactByABAPrefix__c abaPrefixContact:ContactUsContactABAPrefixList)
                        ContactUsContactIDSet.add(abaPrefixContact.Region_Contact__r.Id);
                    
                    categoryList = getData(ContactUsContactIDSet); 
                    if(categoryList.size() > 0) {
                        searchContactUsContact.status = 'success';
                        searchContactUsContact.message = 'ContactUsContact Available';                        
                        searchContactUsContact.categoryList = categoryList;
                        searchContactUsContact.accountName = accountList[0].Name;
                        searchContactUsContact.abaNumber = accountList[0].ABA__c;
                        System.debug('Message :: '+ searchContactUsContact.message);
                    }else{
                        searchContactUsContact.status = 'error';
                        searchContactUsContact.message = 'Please Specify a valid ABA Number';
                        System.debug('Message :: '+ searchContactUsContact.message);    
                    }     
                }
                else {
                    String firstTwoNumber = seachAba.substring(0,2);
                    ContactUsContactABAPrefixList= getContactUsContactByABAPrefix(firstTwoNumber);
                    
                    if(ContactUsContactABAPrefixList.size() > 0) {
                        for(ContactUsContactByABAPrefix__c abaPrefixContact:ContactUsContactABAPrefixList) {
                            ContactUsContactIDSet.add(abaPrefixContact.Region_Contact__r.Id);
                        }                        
                        categoryList = getData(ContactUsContactIDSet);                        
                        if(categoryList.size() > 0) {
                            searchContactUsContact.accountName = accountList[0].Name;
                            searchContactUsContact.abaNumber = accountList[0].ABA__c;
                            searchContactUsContact.categoryList = categoryList;
                            searchContactUsContact.status = 'success';
                            searchContactUsContact.message = 'ContactUsContact Available';
                            System.debug('Message :: '+ searchContactUsContact.message);
                        }
                        else{
                            searchContactUsContact.status = 'error';
                            searchContactUsContact.message = 'Please Specify a valid ABA Number';
                            System.debug('Message :: '+ searchContactUsContact.message);
                        }
                    }
                }
            }
            else if(accountList.size()<=0){
                searchContactUsContact.status = 'error';
                searchContactUsContact.message = 'Please Specify a valid ABA Number';  
                System.debug('Message:: '+ searchContactUsContact.message);
            }
            
        }
        catch (Exception e) {
            System.Debug('Error: ' + e);
        }
        return searchContactUsContact;
    }
    
/**
* This method is used to retrieve all the ContactUsContact__c records based on the prefix entered from ABA number.
*/
    public static List<ContactUsContactByABAPrefix__c> getContactUsContactByABAPrefix (String prefix) {
        return [SELECT id,Name,Region_Contact__r.Id,Region_Contact__r.Name 
                FROM ContactUsContactByABAPrefix__c
                WHERE Prefix__r.Prefix__c =: prefix and Region_Contact__r.Status__c = 'Approved' WITH SECURITY_ENFORCED];
    }
    
    
    public static List<Category> getData(Set<Id> idList) {
        List<ContactUsContact__c> ContactRecordsList = getContactUsContactRecords(idList);
        Map<String,Map<String,ContactUsContact__c>> contactsByCategoriesMap = sortRecordsByCategoryAndSubCategory(ContactRecordsList);
        List<Category> sortedContactsByCategories = parseMapToCategoryWrapper(contactsByCategoriesMap);
        return sortedContactsByCategories;
    }
    
    public static List<ContactUsContact__c> getContactUsContactRecords(Set<Id> idList) {
        List<ContactUsContact__c> ContactUsList = [SELECT Id, Name, Sequence__c, Category__c, SubCategory__c, Email__c, Web_Site__c,Description__c, Phone__c,
                                                    Status__c, Service_Setup_Email__c, Fax__c, Address__c
                                                    FROM ContactUsContact__c
                                                    WHERE Id IN: idList WITH SECURITY_ENFORCED] ;
        return ContactUsList ;
    }
    
    public static Map<String,Map<String,ContactUsContact__c>> sortRecordsByCategoryAndSubCategory(List<ContactUsContact__c> ContactRecordsList) {
        Map<String,Map<String,ContactUsContact__c>> CategoryRecords = new Map<String,Map<String,ContactUsContact__c>>();
        
        for(ContactUsContact__c contact : ContactRecordsList) {
            Map<String,ContactUsContact__c> contactMap = new Map<String,ContactUsContact__c>();
            
            if(CategoryRecords.containsKey(contact.Category__c)) {
                if(contact.Category__c != null) {
                    contactMap = CategoryRecords.get(contact.Category__c);
                    contactMap.put(contact.SubCategory__c,contact); 
                    CategoryRecords.put(contact.Category__c,contactMap);
                }
            }
            else if(!(CategoryRecords.containsKey(contact.Category__c))) {  
                if(contact.Category__c != null) {
                    contactMap.put(contact.SubCategory__c,contact);
                    CategoryRecords.put(contact.Category__c,contactMap);
                }
            }
        }       
        return CategoryRecords;
    }
    
/**
* This method is used to prepare the category list after mapping the values from contact us contact records.
*/
    
    public static List<Category> parseMapToCategoryWrapper(Map<String,Map<String,ContactUsContact__c>> contactsByCategoriesMap) {
        List<Category> contactsByCategoryRecords = new List<Category>();
        
        //category Map
        for(String key : contactsByCategoriesMap.keySet()) {
            Category category = new Category();
            List<SubCategory> subCategoriesList = new List<SubCategory>();
            
            //Sub Category Map
            for(String subkey : contactsByCategoriesMap.get(key).keySet()) {
                List<ContactUsContactDetails> contactUsDetailsList = new List<ContactUsContactDetails>();
                SubCategory subCategory = new SubCategory();
                
                ContactUsContact__c contact = contactsByCategoriesMap.get(key).get(subkey);
                contactUsDetailsList.add(createContactUsDetailsData(contact));
                
                subCategory.subCategoryName = subkey;
                subCategory.isNull = subkey == null ? true :false ; 
                subCategory.ContactUsDetails = contactUsDetailsList; 
                subCategoriesList.add(subCategory);
            }            
            category.categoryName = key;
            category.subCategories = subCategoriesList ;
            contactsByCategoryRecords.add(category);
        }        
        return contactsByCategoryRecords;
    } 
    
    public static ContactUsContactDetails createContactUsDetailsData(ContactUsContact__c contact) {
        ContactUsContactDetails contactDetails = new ContactUsContactDetails();
        contactDetails.address = contact.Address__c;
        contactDetails.category = contact.Category__c;
        contactDetails.description = contact.Description__c;
        contactDetails.email = contact.Email__c;
        contactDetails.mailToLink = 'mailto:'+contact.Email__c;
        contactDetails.fax = contact.Fax__c;
        contactDetails.phone = contact.Phone__c;
        contactDetails.serviceSetupEmail = contact.Service_Setup_Email__c;
        contactDetails.subCategory = contact.SubCategory__c;
        contactDetails.status = contact.Status__c;
        contactDetails.website = contact.Web_Site__c;
        return contactDetails;
    }
    
    public class SearchData {
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public String message {get;set;}
        @AuraEnabled public String abaNumber {get;set;}
        @AuraEnabled public String accountName {get;set;}
        @AuraEnabled public List<Category> categoryList {get;set;}
    }
    
    public class Category {
        @AuraEnabled public String categoryName {get;set;}
        @AuraEnabled public List<SubCategory> subCategories {get;set;}
    }
    
    public class SubCategory {
        @AuraEnabled public String subCategoryName {get;set;}
        @AuraEnabled public Boolean isNull {get;set;}
        @AuraEnabled public List<ContactUsContactDetails> ContactUsDetails {get;set;}
    }
    
    public class ContactUsContactDetails {
        @AuraEnabled public String address {get;set;}
        @AuraEnabled public String category {get;set;}
        @AuraEnabled public String description {get;set;}
        @AuraEnabled public String fax {get;set;}
        @AuraEnabled public String email {get;set;}
        @AuraEnabled public String mailToLink {get;set;}
        @AuraEnabled public String phone {get;set;}
        @AuraEnabled public String serviceSetupEmail {get;set;}
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public String subCategory {get;set;}
        @AuraEnabled public String website {get;set;}
    }
}