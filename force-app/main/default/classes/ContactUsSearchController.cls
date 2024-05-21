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
        String queryString = 'SELECT '+joinFields+' FROM ContactUsContact__c WHERE Id IN :IdList ORDER BY SubCategory__c';
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
        
        User user = new User();
        if(account.AccountExecutive__c != null){
            user = 
            [
                SELECT Id,
                 Name,
                Phone,
                Email 
                FROM User 
                WHERE Id = :account.OwnerId 
                WITH SECURITY_ENFORCED
            ];
        }
        
        for(ContactUs_Column__mdt contactUsColumnMdt :CONTACT_US_COLUMN_METADATA){
            if(contactUsContactRecordsByCategoryMap.containsKey(contactUsColumnMdt.Picklist_Value__c) || contactUsColumnMdt.Picklist_Value__c == 'Relationship Manager'){
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
                    List<ContactUsContact__c> contactUsContactRecords = new List<ContactUsContact__c>();
                    
                    if(contactUsColumnMdt.Picklist_Value__c == 'Relationship Manager' && account != null && user != null){
                        ContactUsContact__c demoRecord = new ContactUsContact__c();
                        demoRecord.Name = 'Demo Record for Relationship Manager';
                        contactUsContactRecords.add(demoRecord); // adding demo record just for "Relationship Manager" table, so for block have 1 loop to create "Relationship Manager" table with a data of Account and User.
                    }else{
                        contactUsContactRecords = contactUsContactRecordsByCategoryMap.get(contactUsColumnMdt.Picklist_Value__c);
                    }
                   
                    for(ContactUsContact__c contact :contactUsContactRecords){
                        List<List<ColumnWrapper>> columnList = new List<List<ColumnWrapper>>();
                        for(String headerName: headers){ 
                            headerName = headerName.trim();
                            if(headerAndFieldsMap.containsKey(headerName)){
                                
                                List<ColumnWrapper> columnData = new List<ColumnWrapper>();
                                
                                List<String> fields = headerAndFieldsMap.get(headerName);
                                Boolean isPhoneType1 = false, isPhoneType2 = false, isPhoneType3 = false;
                                if(fields.contains('Phone_Text__c')){
                                    isPhoneType1 = true;
                                }
                                if(fields.contains('Phone_Text_2__c')){
                                    isPhoneType2 = true;
                                }
                                if(fields.contains('Phone_Text_3__c')){
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
                                        }else  if(!field.contains('Phone_Text')){
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
                    categoryWrapper.containsData = containsData;
                    categoryWrapper.headers = headers;
                    categoryWrapper.tableHeader = tableHeader;
                    if(tableHeader != null){
                        String formattedId = tableHeader.remove('&reg;');
                        formattedId = formattedId.remove('<sup>®</sup>');
                        categoryWrapper.tableId = formattedId;
                    } else {
                        String formattedId = contactUsColumnMdt.Picklist_Value__c.remove('&reg;');
                        formattedId = formattedId.remove('<sup>®</sup>');
                        categoryWrapper.tableId = formattedId;
                        
                    }
                    categoryWrapper.categoryId = contactUsColumnMdt.Picklist_Value__c.remove('&reg;');
                    categoryWrapper.categoryId = categoryWrapper.categoryId.remove('<sup>®</sup>');
                    if(headers.size() == 2){
                        List<String> columnWidths = new List<String>(2);
                        columnWidths[0] = 'slds-size_4-of-12';
                        columnWidths[1] = 'slds-size_8-of-12';
                        categoryWrapper.styles = columnWidths;
                    } else if(headers.size() == 3){
                        List<String> columnWidths = new List<String>(3);
                        columnWidths[0] = 'slds-size_4-of-12';
                        columnWidths[1] = 'slds-size_4-of-12';
                        columnWidths[2] = 'slds-size_4-of-12';
                        categoryWrapper.styles = columnWidths;
                    } else if(headers.size() == 4){
                        List<String> columnWidths = new List<String>(4);
                        columnWidths[0] = 'slds-size_4-of-12';
                        columnWidths[1] = 'slds-size_2-of-12';
                        columnWidths[2] = 'slds-size_2-of-12';
                        columnWidths[3] = 'slds-size_4-of-12';
                        categoryWrapper.styles = columnWidths;
                    }
                    categoryWrapper.themeBreak = false;
                    categoryWrapperList.add(categoryWrapper);
                }
                
            }
        }
        //The below lines are to set unique column styling for specific tables
        if(categoryWrapperList[categoryWrapperList.size()-1].headers.size() == 2){
            List<String> columnWidthsExceptionSize = new List<String>(2);
            columnWidthsExceptionSize[0] = 'slds-size_8-of-12';
            columnWidthsExceptionSize[1] = 'slds-size_4-of-12';
            categoryWrapperList[categoryWrapperList.size()-1].styles = columnWidthsExceptionSize;
        }

        //adding theme break to display after a specific table
        categoryWrapperList[1].themeBreak = true;
        
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
        @AuraEnabled public String tableId {get;set;}
        @AuraEnabled public String categoryId {get;set;}
        @AuraEnabled public List<List<List<ColumnWrapper>>> columnData {get;set;}
        @AuraEnabled public List<String> styles {get;set;}
        @AuraEnabled public Object tableBottomDescription {get;set;}
        @AuraEnabled public Boolean themeBreak {get;set;}
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
            
            this.style = isDescription ? 'font-weight: 400 !important;' : '';
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
                this.label = value;
                value = setformatPhoneNumber(value);
                this.value = value;
            }
            else if(valueType == 'FAX' && value != null){
                this.isFax = true;
            }
            else if(valueType == 'URL' && value != null){
                this.isUrl = true;
            }

            if(phoneTypeValue != null && JSON.serialize(phoneTypeValue).containsNone(',')){
                this.phoneTypeValue = ' ' + phoneTypeValue;
            }
            
            if(phoneTypeValue2 != null){
                this.isPhoneType2 = true;
                this.isPhone = false;
                if(JSON.serialize(phoneTypeValue2).containsNone(',')){
                    this.phoneTypeValue2 = ' ' + phoneTypeValue2;
                }
            } 
            
            if(phoneTypeValue3 != null){
                this.isPhoneType3 = true;
                this.isPhone = false;
                if(JSON.serialize(phoneTypeValue3).containsNone(',')){
                    this.phoneTypeValue3 = ' ' + phoneTypeValue3;
                }
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

    public static Object setformatPhoneNumber(Object phoneNumber){
        string nonNumbers ='[^0-9]';
        Object formattedNumber;
        formattedNumber = 'tel:+1' + JSON.serialize(phoneNumber).replaceAll(nonNumbers, '');
        return formattedNumber;
    }
    
}
/*
trigger ContactUsContactTrigger on ContactUsContact__c (before insert, before update, before delete, after insert, after update) {
    
    System.TriggerOperation triggerEvent = trigger.operationType;
    boolean sys_adm =FeatureManagement.checkPermission('System_Administrator');
    public static boolean isapproval =false;
    switch on triggerEvent {
        when BEFORE_INSERT {
            for(ContactUsContact__c con : Trigger.New) {
                system.debug('PG:BI: new status: '+con.Status__c+ ' clone: '+con.IsCloned__c );
            	if(con.IsCloned__c){
                    con.addError('You cannot clone from a cloned record.');
                }
                if(con.isClone() && con.Status__c == 'Approved'){
                    con.Status__c = 'Preview';
                }
                if(con.isClone() && con.Status__c == 'Preview'){
                    con.IsCloned__c = true;
                }    
            }
        }
        when AFTER_INSERT {}
        
        when BEFORE_UPDATE {
            Map<Id, ContactUsContact__c> oldMap = Trigger.OldMap;
            for(ContactUsContact__c con : Trigger.New) {
                ContactUsContact__c oldCon = oldMap.get(con.Id);
                system.debug('PG:BU: new status: '+con.Status__c+ ' clone: '+con.IsCloned__c );
                system.debug('PG:BU: old status: '+oldCon.Status__c+ ' clone: '+oldCon.IsCloned__c );
                system.debug('PG:isapproval value: '+isapproval);
                if(con.Status__c == 'Approved' && oldCon.Status__c == 'Approved' && !oldCon.IsCloned__c && isapproval ){ //&& !con.Is_Approved__c && !sys_adm
                    con.addError('You should not edit original record but clone and update the value and then submit for approval.');
                }
                if(con.Status__c == 'Preview' && oldCon.Status__c == 'Approved' && !oldCon.IsCloned__c){ //&& !con.Is_Approved__c
                    con.addError('You should not edit original record but clone and update the value and then submit for approval.');
                }
                if(con.IsCloned__c && oldCon.Status__c == 'Preview' && con.Status__c == 'Approved' && con.ProcessedDate__c==null){
                    con.Status__c.addError('You cannot update clone record status field. It will get update by approval process.');//Approver personna not able to approve 
                }
                if(con.IsCloned__c && oldCon.Status__c == 'Preview' && (con.Status__c == 'Approved' || con.Status__c == 'Rejected') && con.OwnerId == con.LastModifiedById){
                    con.Status__c.addError('You cannot be a Submitter/Admin and Approver of a record at same time.');
                }
            }
        }
        when AFTER_UPDATE{
            Map<Id, ContactUsContact__c> oldMap = Trigger.OldMap;
            List<Id> con_del = new List<Id>();
            List<ContactUsContact__c> contactUsContactToUpdate = new List<ContactUsContact__c>();
            List<ContactUsContact__c> org_Records = [SELECT Id, Name,Is_Secondary_Indicator__c, Email__c, Address__c, Phone__c, Fax__c, Sequence__c, Web_Site__c, Service_Setup_Email__c, Category__c, SubCategory__c, Contact_Email_Label__c, Primary_Contact_Email_Label__c, Name__c, Primary_Contact_Email__c, Primary_Contact_Fax__c, Primary_Contact_Phone__c, Return_completed_original_docs_to__c, Return_draft_docs_for_initial_review__c, Secondary_Contact_Email_Label__c, Secondary_Contact_Email__c, Secondary_Contact_Fax__c, Secondary_Contact_Phone__c, District__c, Name_2__c, Name_3__c, Phone_2__c, Phone_3__c, Secondary_Contact_Name_2__c, Secondary_Contact_Name__c, Secondary_Contact_Phone_2__c, Website_Label__c, Bank_Name__c, Mailbox__c, Return_draft_doc_Email__c, Return_draft_doc_Fax__c, Contact_Us_Contact_Name__c, Phone_Text__c, Is_Approved__c, Phone_Text_2__c, Phone_Text_3__c FROM ContactUsContact__c 
                                                     where IsCloned__c= false and Processeddate__c = null and Status__c='Approved' ];
            List<ProcessInstance> proc_inst = [Select LastActor.name,TargetObjectid, TargetObject.name, Status, SubmittedBy.Name,createdbyId,CompletedDate FROM ProcessInstance ];
            List<ContactUsApprovalHistory__c> conhistupd= new List<ContactUsApprovalHistory__c>();
            
           for(ContactUsContact__c con : Trigger.New) {
                ContactUsContact__c oldCon = oldMap.get(con.Id);
               system.debug('PG:AU: new status: '+con.Status__c+ ' clone: '+con.IsCloned__c );
               system.debug('PG:AU: old status: '+oldCon.Status__c+ ' clone: '+con.IsCloned__c );
               system.debug('PG:isapproval value: '+isapproval);
            
                for(ContactUsContact__c cc : org_Records){
                    if(cc.Name == con.Name && con.IsCloned__c == true && con.Status__c == 'Approved'){
                        //ContactUsContact__c nw_cc = new ContactUsContact__c();
                        cc.Description__c = con.Description__c;
                        cc.Address__c = con.Address__c;
                        cc.Phone__c = con.Phone__c;
                        cc.Bank_Name__c = con.Bank_Name__c;
                        contactUsContactToUpdate.add(cc); 
                        isapproval= true;
                    }
                    if(cc.Name == con.Name && con.IsCloned__c == true && (con.Status__c == 'Approved' || con.Status__c == 'Rejected'|| con.Status__c == 'Recalled')){
                        con_del.add(con.Id);
                    }
                    
                    for(ProcessInstance pi : proc_inst){
                        if(cc.Name == con.Name && con.IsCloned__c == true && con.Status__c == 'Approved' && pi.TargetObjectId==con.Id){
                            ContactUsApprovalHistory__c conhist =  new ContactUsApprovalHistory__c();
                            conhist.Name = cc.Name;
                            conhist.Status__c= pi.Status;
                            conhist.Submitter__c = pi.SubmittedBy.Name;
                            conhist.Approver__c = pi.LastActor.name;
                            conhist.Date__c = pi.CompletedDate;
                            conhist.TargetObjectId__c = cc.Id;
                            conhistupd.add(conhist);
                            
                        }
                    }
                }
            }
            system.debug('PG: Going to delete');
            update contactUsContactToUpdate;
            insert conhistupd;
            Database.delete(con_del);
        }
    }   
}
*/