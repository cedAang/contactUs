public with sharing class ContactUsSearchController {
    
    static List<ContactUs_Column__mdt> CONTACT_US_COLUMN_METADATA = 
        [
            SELECT Id, 
            Label, 
            Picklist_Value__c, 
            District_Name__c,
            Header_Value__c, 
            Table_Header__c,
            Table_Order__c,
            Table_Bottom_Description__c
            FROM ContactUs_Column__mdt
            WITH SECURITY_ENFORCED
            ORDER BY Table_Order__c
            
        ];
    
    static List<Column_Header_and_Fields__mdt> COLUMN_HEADER_AND_FIELDS_METADATA = 
        [
            SELECT Id, 
            Label, 
            ContactUs_Column__c, 
            ContactUs_Column__r.Label,
            Field_API_Names__c,
            Header__c
            FROM Column_Header_and_Fields__mdt
            WITH SECURITY_ENFORCED
        ];
    
    @AuraEnabled(cacheable=true)
    public static SearchData getContactDetails(String abaNumber) {
        SearchData searchContactUsContact = new SearchData();
        searchContactUsContact.categoryList = new List<CategoryWrapper>();
        
        try{
            String seachAba = String.escapeSingleQuotes(abaNumber);
            
            List<Account> accountList = new List<Account>();
            accountList = [SELECT id, Name, ABA__c, AccountExecutive__c , OwnerId
                           FROM Account
                           WHERE ABA__c =: seachAba WITH SECURITY_ENFORCED];
            
            if(accountList.size() == 0){
                searchContactUsContact.status = 'error';
                searchContactUsContact.message = 'Please Specify a valid ABA Number';  
            }
            
            if(accountList.size() > 0){
                
                List<ContactUsContactByABAPrefix__c> contactUsContactABAPrefixList = new List<ContactUsContactByABAPrefix__c>();
                
                // search contacts by 1st 4 numbers
                String firstFourNumber = seachAba.substring(0,4);
                contactUsContactABAPrefixList= getContactUsContactByABAPrefixRecords(firstFourNumber);
                
                // if contacts does not found by 1st 4 numbers then search contacts by 1st 2 numbers
                if(contactUsContactABAPrefixList.size() == 0){
                    String firstTwoNumber = seachAba.substring(0,2);
                    contactUsContactABAPrefixList= getContactUsContactByABAPrefixRecords(firstTwoNumber);
                }
                
                if(contactUsContactABAPrefixList.size() > 0) {
                    
                    Set<Id> contactUsContactIDSet = new Set<Id>();
                    String districtName = '';
                    
                    for(ContactUsContactByABAPrefix__c abaPrefixContact:contactUsContactABAPrefixList){
                        if(abaPrefixContact.Region_Contact__c != null){
                            contactUsContactIDSet.add(abaPrefixContact.Region_Contact__r.Id);
                            
                            if(abaPrefixContact.Prefix__c != null 
                               && abaPrefixContact.Prefix__r.District_Name__c != null 
                               && String.isBlank(districtName)){
                                districtName = abaPrefixContact.Prefix__r.District_Name__c;
                            }
                        }
                    }

                    List<CategoryWrapper> categoryList = new List<CategoryWrapper>(); 
                    categoryList = getData(contactUsContactIDSet, districtName, accountList[0]); 
                    
                    if(categoryList.size() > 0) {
                        searchContactUsContact.status = 'success';
                        searchContactUsContact.message = 'ContactUsContact Available';                        
                        searchContactUsContact.accountName = accountList[0].Name;
                        searchContactUsContact.abaNumber = accountList[0].ABA__c;
                        searchContactUsContact.categoryList = categoryList;
                    }else{
                        searchContactUsContact.status = 'error';
                        searchContactUsContact.message = 'Please Specify a valid ABA Number';
                    }     
                    
                }else{
                    searchContactUsContact.status = 'error';
                    searchContactUsContact.message = 'Please Specify a valid ABA Number';
                }
                
            }
            
        }catch (Exception e) {
            System.Debug('Error: ' + e.getMessage()+'Line Number '+e.getLineNumber()+ 'Cause'+ e.getCause());
            searchContactUsContact.status = 'error';
            searchContactUsContact.message = 'Something went wrong';
        }
        
        return searchContactUsContact;
    }
    
    public static List<ContactUsContactByABAPrefix__c> getContactUsContactByABAPrefixRecords(String prefix) {
        List<String> fields = new List<String>(getFields('ContactUsContactByABAPrefix__c').keySet());
        fields.add('Region_Contact__r.Name');
        fields.add('Prefix__r.District_Name__c');
        String queryString = 'SELECT '+String.join(fields, ', ')+' FROM ContactUsContactByABAPrefix__c WHERE Prefix__r.Prefix__c = :prefix AND Region_Contact__r.Status__c = \'Approved\'';
        return Database.query(queryString);        
    }
    
    public static List<ContactUsContact__c> getContactUsContactRecords(Set<Id> IdList) {
        List<String> fields = new List<String>(getFields('ContactUsContact__c').keySet());
        String joinFields = String.escapeSingleQuotes(String.join(fields, ', '));
        String queryString = 'SELECT '+joinFields+' FROM ContactUsContact__c WHERE Id IN :IdList';
        return Database.query(queryString);
    }
    
    public static List<CategoryWrapper> getData(Set<Id> idList,  String districtName, Account account){
        List<ContactUsContact__c> contactUsContactRecords = getContactUsContactRecords(idList);
        Map<String, List<ContactUsContact__c>> contactUsContactRecordsByCategoryMap = sortRecordsByCategory(contactUsContactRecords);
        List<CategoryWrapper> categoryWrapper = parseMapToCategoryWrapper(contactUsContactRecordsByCategoryMap, districtName, account);
        return categoryWrapper;
    }
    
    public static Map<String, List<ContactUsContact__c>> sortRecordsByCategory(List<ContactUsContact__c> contactUsContactRecords) {
        Map<String, List<ContactUsContact__c>> categoryRecords = new Map<String,List<ContactUsContact__c>>();
        for(ContactUsContact__c contact : contactUsContactRecords) {   
            if(contact.Category__c != null) {
                if(categoryRecords.containsKey(contact.Category__c)) {
                    List<ContactUsContact__c> contactUsContactList = categoryRecords.get(contact.Category__c);
                    contactUsContactList.add(contact); 
                    categoryRecords.put(contact.Category__c, contactUsContactList);
                }
                else{  
                    categoryRecords.put(contact.Category__c, new List<ContactUsContact__c>{contact});
                }
            }
        } 
        return categoryRecords;
    }
    
    public static List<CategoryWrapper> parseMapToCategoryWrapper(Map<String, List<ContactUsContact__c>> contactUsContactRecordsByCategoryMap, String districtName, Account account){
        
        Map<String, Map<String, List<String>>> columnHeaderAndFieldsMap = new Map<String, Map<String, List<String>>>();
        for(Column_Header_and_Fields__mdt columnHeaderMdt :COLUMN_HEADER_AND_FIELDS_METADATA){
            if(columnHeaderMdt.Header__c != null && columnHeaderMdt.Field_API_Names__c != null){
                Map<String, List<String>> headerAndFieldsMap = new Map<String, List<String>>();
                if(columnHeaderAndFieldsMap.containsKey(columnHeaderMdt.ContactUs_Column__c)){
                    headerAndFieldsMap = columnHeaderAndFieldsMap.get(columnHeaderMdt.ContactUs_Column__c);
                }
                if(columnHeaderMdt.Field_API_Names__c.contains(',')){
                    headerAndFieldsMap.put(columnHeaderMdt.Header__c.trim(), columnHeaderMdt.Field_API_Names__c.split(','));
                }else{
                    headerAndFieldsMap.put(columnHeaderMdt.Header__c.trim(), new List<String>{columnHeaderMdt.Field_API_Names__c});
                }
                columnHeaderAndFieldsMap.put(columnHeaderMdt.ContactUs_Column__c, headerAndFieldsMap);
            }
            
        }
        
        List<CategoryWrapper> categoryWrapperList = new List<CategoryWrapper>();
        Map<String, String> fieldTypeMap = getFieldsAndItsTypeMap('ContactUsContact__c');
        Map<String, String> userFieldTypeMap = getFieldsAndItsTypeMap('User');
        Map<String, String> accountFieldTypeMap = getFieldsAndItsTypeMap('Account');
        User user = [SELECT Id, Name, Phone, Email FROM User WHERE Id = :account.OwnerId];
        
        for(ContactUs_Column__mdt contactUsColumnMdt :CONTACT_US_COLUMN_METADATA){
            if(contactUsContactRecordsByCategoryMap.containsKey(contactUsColumnMdt.Picklist_Value__c)){
                Boolean containsData = false;
                List<String> headers = new List<String>();
                String headerValues = '';
                String tableHeader = '';
                
                if(contactUsColumnMdt.District_Name__c != null){
                    if(contactUsColumnMdt.District_Name__c == districtName){
                        headerValues = contactUsColumnMdt.Header_Value__c;
                        tableHeader = contactUsColumnMdt.Table_Header__c;
                    }
                }else{
                    headerValues = contactUsColumnMdt.Header_Value__c;
                    tableHeader = contactUsColumnMdt.Table_Header__c;
                }
                
                if(String.isNotBlank(headerValues)){
                    if(headerValues.contains(',')){
                        headers = headerValues.split(',');
                    }else
                    {
                        headers = new List<String>{headerValues};   
                    }
                }
                
                if(headers.size() > 0){
                    CategoryWrapper categoryWrapper = new CategoryWrapper();
                    categoryWrapper.columnData = new List<List<List<ColumnWrapper>>>();
                    
                    Map<String, List<String>> headerAndFieldsMap = columnHeaderAndFieldsMap.get(contactUsColumnMdt.Id);
                    List<ContactUsContact__c> contactUsContactRecords = contactUsContactRecordsByCategoryMap.get(contactUsColumnMdt.Picklist_Value__c);
                   
                    for(ContactUsContact__c contact :contactUsContactRecords){
                            List<List<ColumnWrapper>> columnList = new List<List<ColumnWrapper>>();
                            for(String headerName: headers){ 
                                headerName = headerName.trim();
                                if(headerAndFieldsMap.containsKey(headerName)){
                                    
                                    List<ColumnWrapper> columnData = new List<ColumnWrapper>();
                                    
                                    List<String> fields = headerAndFieldsMap.get(headerName);
                                    Boolean isPhoneType1 = false, isPhoneType2 = false, isPhoneType3 = false;
                                    if(fields.contains('Phone_Text__c')){
                                        fields.remove(fields.indexOf('Phone_Text__c'));
                                        isPhoneType1 = true;
                                    }
                                    if(fields.contains('Phone_Text_2__c')){
                                        fields.remove(fields.indexOf('Phone_Text_2__c'));
                                        isPhoneType2 = true;
                                    }
                                    if(fields.contains('Phone_Text_3__c')){
                                        fields.remove(fields.indexOf('Phone_Text_3__c'));
                                        isPhoneType3 = true;
                                    }
                                    
                                    Object emailLabel = '';
                                    Object websiteLabel = '';
                                    
                                    for(String field :fields){ 
                                        field = field.trim();
                                        
                                        if(field.contains(':')){
                                            List<String> splitList = field.split(':');
                                            if(splitList[0] == 'Account'){
                                                if(account.get(splitList[1]) != null){
                                                    columnData.add( 
                                                        new ColumnWrapper(
                                                            account.get(splitList[1]), 
                                                            accountFieldTypeMap.get(splitList[1]), 
                                                            '', 
                                                            false, 
                                                            null, 
                                                            null,
                                                            null
                                                        )
                                                    );
                                                }
                                            }else if(splitList[0] == 'User'){
                                                if(user.get(splitList[1]) != null){
                                                    columnData.add( 
                                                        new ColumnWrapper(
                                                            user.get(splitList[1]), 
                                                            userFieldTypeMap.get(splitList[1]), 
                                                            splitList[1] == 'Email' ? System.Label.Relationship_Manager_Email_Label : '', 
                                                            false, 
                                                            null, 
                                                            null,
                                                            null
                                                        )
                                                    );
                                                }
                                            }
                                        }else{
                                            if(field.contains('Email_Label')){
                                                emailLabel = contact.get(field);
                                            }else if(field.contains('Website_Label')) {
                                                websiteLabel = contact.get(field);
                                            }else{
                                                Object label = '';
                                                if(field.contains('Email')){
                                                    label = emailLabel;
                                                    emailLabel = '';
                                                }  
                                                if(field.contains('Web_Site__c')) {
                                                    label = websiteLabel;
                                                    websiteLabel = '';
                                                }
                                                
                                                Object valueType = fieldTypeMap.get(field);
                                                if(field.contains('Fax')){
                                                    valueType = 'FAX';
                                                }
                                                
                                                if(contact.get(field) != null){
                                                    columnData.add( 
                                                        new ColumnWrapper(
                                                            contact.get(field), 
                                                            valueType, 
                                                            label, 
                                                            field == 'Description__c', 
                                                            (field == 'Phone__c' && isPhoneType1) ? contact.get('Phone_Text__c') : null, 
                                                            (field == 'Phone_2__c' && isPhoneType2) ? contact.get('Phone_Text_2__c') : null,
                                                            (field == 'Phone_3__c' && isPhoneType3) ? contact.get('Phone_Text_3__c') : null
                                                        )
                                                    );
                                                }
                                            }
                                        }
                                    }
                                    columnList.add(columnData);
                                    if(columnData.size() > 0){
                                        containsData = true;
                                    }
                                }
                                
                            }
                            categoryWrapper.columnData.add(columnList);
                            
                        }
                    
                    
                    if(contactUsColumnMdt.Picklist_Value__c != tableHeader){
                        categoryWrapper.categoryName = contactUsColumnMdt.Picklist_Value__c;
                    }
                    categoryWrapper.tableBottomDescription = contactUsColumnMdt.Table_Bottom_Description__c;
                    categoryWrapper.headers = headers;
                    categoryWrapper.tableHeader = tableHeader;
                    categoryWrapper.containsData = containsData;
                    categoryWrapperList.add(categoryWrapper);
                }
                
            }
        }
        
        return categoryWrapperList;
        
    }
    
    public class SearchData {
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public String message {get;set;}
        @AuraEnabled public String abaNumber {get;set;}
        @AuraEnabled public String accountName {get;set;}
        @AuraEnabled public List<CategoryWrapper> categoryList {get;set;}
    }
    
    public class CategoryWrapper {
        @AuraEnabled public Boolean containsData {get;set;}
        @AuraEnabled public String categoryName {get;set;}
        @AuraEnabled public List<String> headers {get;set;}
        @AuraEnabled public String tableHeader {get;set;}
        @AuraEnabled public List<List<List<ColumnWrapper>>> columnData {get;set;}
        @AuraEnabled public Object tableBottomDescription {get;set;}
    }
    
    public class ColumnWrapper{
        @AuraEnabled public Boolean isText {get;set;}
        @AuraEnabled public Boolean isTextArea {get;set;}
        @AuraEnabled public Boolean isEmail {get;set;}
        @AuraEnabled public Boolean isPhone {get;set;}
        @AuraEnabled public Boolean isFax {get;set;}
        @AuraEnabled public Boolean isUrl {get;set;}
        @AuraEnabled public Boolean isDescription {get;set;}
        @AuraEnabled public Boolean isPhoneType2 {get;set;}
        @AuraEnabled public Boolean isPhoneType3 {get;set;}
        
        @AuraEnabled public Object label {get;set;}
        @AuraEnabled public Object value {get;set;}
        @AuraEnabled public Object phoneTypeValue {get;set;}
        @AuraEnabled public Object phoneTypeValue2 {get;set;}
        @AuraEnabled public Object phoneTypeValue3 {get;set;}
        
        @AuraEnabled public String style {get;set;}
        
        public ColumnWrapper(Object value, Object valueType, Object label, Boolean isDescription, Object phoneTypeValue, Object phoneTypeValue2, Object phoneTypeValue3){
            this.label = label;
            this.value = value;
            this.phoneTypeValue = phoneTypeValue;
            this.phoneTypeValue2 = phoneTypeValue2;
            this.phoneTypeValue3 = phoneTypeValue3;
            
            this.style = isDescription ? 'font-weight: 300;' : '';
            this.isDescription = isDescription;
            
            if((valueType == 'STRING' || valueType == 'PICKLIST') && value != null){
                this.isText = true;
            }
            else if(valueType == 'TEXTAREA' && value != null){
                this.isTextArea = true;
            }
            else if(valueType == 'EMAIL' && value != null){
                this.isEmail = true;
            }
            else if(valueType == 'PHONE' && value != null){
                this.isPhone = true;
            }
            else if(valueType == 'FAX' && value != null){
                this.isFax = true;
            }
            else if(valueType == 'URL' && value != null){
                this.isUrl = true;
            }
            
            if(phoneTypeValue2 != null){
                this.isPhoneType2 = true;
                this.isPhone = false;
            } 
            
            if(phoneTypeValue3 != null){
                this.isPhoneType3 = true;
                this.isPhone = false;
            } 
        }
    }
    
    public static Map<String, String> getFieldsAndItsTypeMap(String objectName){
        Map<String, Schema.SObjectField> mapofField = getFields(objectName);
        Map<String, String> fieldTypeMap = new Map<String, String>();
        for(String fieldName : MapofField.keySet()) {
            Schema.SObjectField field = MapofField.get(fieldName);
            Schema.DescribeFieldResult F = field.getDescribe();
            fieldTypeMap.put(String.valueOf(field), String.valueOf(F.getType()));
        }
        return fieldTypeMap;
    }
    
    public static Map<String, Schema.SObjectField> getFields(String objectName){
        Map <String,Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType sobjType = gd.get(objectName);
        Schema.DescribeSObjectResult r = sobjType.getDescribe();
        return r.fields.getMap();
    }
    
}