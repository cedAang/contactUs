public with sharing class ContUsContWithMethodsDefinition {
   
    /**
    * Description: A static variable that retrieves metadata for "Contact Us" columns from a custom metadata type.
    * 
    * This list contains the metadata records used to configure the "Contact Us" table. The data includes:
    * - Column identifiers and labels.
    * - District names for filtering specific configurations.
    * - Header and footer information for table display.
    * 
    * The metadata records are fetched with enforced field-level security and ordered by the Table_Order__c field.
    * 
    * @return List<ContactUs_Column__mdt> A static list of "Contact Us" column metadata records.
    */

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

    
    /**
    * Description: A static variable that retrieves metadata for column headers and their associated fields from a custom metadata type.
    * 
    * This list contains the metadata records that map column headers to specific fields for the "Contact Us" table. 
    * It includes:
    * - Column identifiers and labels.
    * - Associated field API names for data retrieval.
    * - Header names for table display.
    * 
    * The metadata records are fetched with enforced field-level security.
    * 
    * @return List<Column_Header_and_Fields__mdt> A static list of metadata records mapping column headers to fields.
    */

    
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


    /**
     * Description: Retrieves contact details based on the provided ABA number.
     *
     * @param abaNumber The ABA number used to search for contact details.
     * @return The SearchData object containing contact details.
     */
    @AuraEnabled(cacheable=true)
    public static SearchData getContactDetails(String abaNumber) {
        SearchData searchContactUsContact = new SearchData();
        searchContactUsContact.categoryList = new List<CategoryWrapper>();
        
        try{
            String searchAba = String.escapeSingleQuotes(abaNumber);
            
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
            searchContactUsContact.message = 'Your request could not be completed at this time, please try again';
        }
        
        return searchContactUsContact;
    }

    /**
     * Description: Retrieves ContactUsContactByABAPrefix records for the specified prefix.
     *
     * @param prefix The prefix to search for ContactUsContactByABAPrefix records.
     * @return A list of ContactUsContactByABAPrefix records matching the prefix.
     */
    public static List<ContactUsContactByABAPrefix__c> getContactUsContactByABAPrefixRecords(String prefix) {
        List<String> fields = new List<String>(getFields('ContactUsContactByABAPrefix__c').keySet());
        fields.add('Region_Contact__r.Name');
        fields.add('Prefix__r.District_Name__c');
        String queryString = 'SELECT '+String.join(fields, ', ')+' FROM ContactUsContactByABAPrefix__c WHERE Prefix__r.Prefix__c = :prefix AND Region_Contact__r.Status__c = \'Approved\'';
        return Database.query(queryString);        
    }

    /**
     * Description: Retrieves ContactUsContact records based on the specified list of IDs.
     *
     * @param IdList A set of IDs used to search for ContactUsContact records.
     * @return A list of ContactUsContact records matching the IDs.
     */
    private static List<ContactUsContact__c> getContactUsContactRecords(Set<Id> IdList) {
        List<String> fields = new List<String>(getFields('ContactUsContact__c').keySet());
        String joinFields = String.escapeSingleQuotes(String.join(fields, ', '));
        String queryString = 'SELECT '+joinFields+' FROM ContactUsContact__c WHERE Id IN :IdList ORDER BY SubCategory__c';
        return Database.query(queryString);
    }


    /**
     * Description: Retrieves data for the specified set of IDs, district name, and account.
     *
     * @param idList The set of IDs to search for data.
     * @param districtName The district name used for additional filtering.
     * @param account The account used for additional filtering.
     * @return A list of CategoryWrapper objects containing the data.
     */
    private static List<CategoryWrapper> getData(Set<Id> idList,  String districtName, Account account){
        List<ContactUsContact__c> contactUsContactRecords = getContactUsContactRecords(idList);
        Map<String, List<ContactUsContact__c>> contactUsContactRecordsByCategoryMap = sortRecordsByCategory(contactUsContactRecords);
        List<CategoryWrapper> categoryWrapper = parseMapToCategoryWrapper(contactUsContactRecordsByCategoryMap, districtName, account);
        return categoryWrapper;
    }
    
    /**
     * Description: Sorts ContactUsContact records by category.
     *
     * @param contactUsContactRecords The list of ContactUsContact records to sort.
     * @return A map of category names to lists of ContactUsContact records.
     */
    private static Map<String, List<ContactUsContact__c>> sortRecordsByCategory(List<ContactUsContact__c> contactUsContactRecords) {
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
    /**
     * Description: Parses a map of ContactUsContact records by category into a list of CategoryWrapper objects.
     *
     * @param contactUsContactRecordsByCategoryMap A map of ContactUsContact records by category.
     * @param districtName The district name used for additional filtering.
     * @param account The account used for additional filtering.
     * @return A list of CategoryWrapper objects representing the data.
     */
    private static List<CategoryWrapper> parseMapToCategoryWrapper(Map<String, List<ContactUsContact__c>> contactUsContactRecordsByCategoryMap, String districtName, Account account){
        
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

        Boolean displayAccountExecutive = account.Relationship_Manager_Email__c == null && account.Relationship_Manager_Name__c == null && account.Relationship_Manager_Phone__c == null ? true : false; 
        
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
    
    /**
    * Description: Represents the search result data structure for "Contact Us" details.
    * It includes status, message, ABA number, account name, and a list of category wrappers.
    */
    public class SearchData {
        
        /** 
        * Description: Status of the search operation, e.g., 'success' or 'error'.
        */
        @AuraEnabled public String status { get; set; }
        
        /** 
        * Description: Message providing additional context about the search operation result.
        */
        @AuraEnabled public String message { get; set; }
        
        /** 
        * Description: The ABA number related to the search.
        */
        @AuraEnabled public String abaNumber { get; set; }
        
        /** 
        * Description: Name of the account related to the search.
        */
        @AuraEnabled public String accountName { get; set; }
        
        /** 
        * Description: List of category wrappers containing details for the "Contact Us" categories.
        */
        @AuraEnabled public List<CategoryWrapper> categoryList { get; set; }
    }
    
    /**
    * Description: Represents a category in the "Contact Us" details table. 
    * Contains metadata such as headers, table styles, and data for rendering.
    */
    public class CategoryWrapper {
        
        /** 
        * Description: Indicates whether this category contains data.
        */
        @AuraEnabled public Boolean containsData { get; set; }
        
        /** 
        * Description: Name of the category.
        */
        @AuraEnabled public String categoryName { get; set; }
        
        /** 
        * Description: List of headers associated with the category table.
        */
        @AuraEnabled public List<String> headers { get; set; }
        
        /** 
        * Description: Header text displayed at the top of the category table.
        */
        @AuraEnabled public String tableHeader { get; set; }
        
        /** 
        * Description: Unique ID for the table representing this category.
        */
        @AuraEnabled public String tableId { get; set; }
        
        /** 
        * Description: Unique ID for the category.
        */
        @AuraEnabled public String categoryId { get; set; }
        
        /** 
        * Description: Multidimensional list containing the column data for rendering.
        */
        @AuraEnabled public List<List<List<ColumnWrapper>>> columnData { get; set; }
        
        /** 
        * Description: List of styles for the table's columns.
        */
        @AuraEnabled public List<String> styles { get; set; }
        
        /** 
        * Description: Text or object providing additional details at the bottom of the table.
        */
        @AuraEnabled public Object tableBottomDescription { get; set; }
        
        /** 
        * Description: Indicates whether a theme break should be displayed after the category.
        */
        @AuraEnabled public Boolean themeBreak { get; set; }
    }


    /**
    * Description: Represents a category in the "Contact Us" details table. 
    * Contains metadata such as headers, table styles, and data for rendering.
    */
    public class CategoryWrapper {
        
        /** 
        * Description: Indicates whether this category contains data.
        */
        @AuraEnabled public Boolean containsData { get; set; }
        
        /** 
        * Description: Name of the category.
        */
        @AuraEnabled public String categoryName { get; set; }
        
        /** 
        * Description: List of headers associated with the category table.
        */
        @AuraEnabled public List<String> headers { get; set; }
        
        /** 
        * Description: Header text displayed at the top of the category table.
        */
        @AuraEnabled public String tableHeader { get; set; }
        
        /** 
        * Description: Unique ID for the table representing this category.
        */
        @AuraEnabled public String tableId { get; set; }
        
        /** 
        * Description: Unique ID for the category.
        */
        @AuraEnabled public String categoryId { get; set; }
        
        /** 
        * Description: Multidimensional list containing the column data for rendering.
        */
        @AuraEnabled public List<List<List<ColumnWrapper>>> columnData { get; set; }
        
        /** 
        * Description: List of styles for the table's columns.
        */
        @AuraEnabled public List<String> styles { get; set; }
        
        /** 
        * Description: Text or object providing additional details at the bottom of the table.
        */
        @AuraEnabled public Object tableBottomDescription { get; set; }
        
        /** 
        * Description: Indicates whether a theme break should be displayed after the category.
        */
        @AuraEnabled public Boolean themeBreak { get; set; }
    }




    /**
    * Description: Represents a column in a "Contact Us" table row. 
    * It encapsulates the column's value, type, formatting, and additional metadata.
    */
    public class ColumnWrapper {
        
        /** 
        * Description: Indicates whether the value is of type text.
        */
        @AuraEnabled public Boolean isText { get; set; }
        
        /** 
        * Description: Indicates whether the value is of type text area.
        */
        @AuraEnabled public Boolean isTextArea { get; set; }
        
        /** 
        * Description: Indicates whether the value is of type email.
        */
        @AuraEnabled public Boolean isEmail { get; set; }
        
        /** 
        * Description: Indicates whether the value is of type phone.
        */
        @AuraEnabled public Boolean isPhone { get; set; }
        
        /** 
        * Description: Indicates whether the value is of type fax.
        */
        @AuraEnabled public Boolean isFax { get; set; }
        
        /** 
        * Description: Indicates whether the value is of type URL.
        */
        @AuraEnabled public Boolean isUrl { get; set; }
        
        /** 
        * Description: Indicates whether the value is a description.
        */
        @AuraEnabled public Boolean isDescription { get; set; }
        
        /** 
        * Description: Indicates whether the value is of phone type 2.
        */
        @AuraEnabled public Boolean isPhoneType2 { get; set; }
        
        /** 
        * Description: Indicates whether the value is of phone type 3.
        */
        @AuraEnabled public Boolean isPhoneType3 { get; set; }
        
        /** 
        * Description: Label associated with the column value, if any.
        */
        @AuraEnabled public Object label { get; set; }
        
        /** 
        * Description: Value to be displayed in the column.
        */
        @AuraEnabled public Object value { get; set; }
        
        /** 
        * Description: Additional value for phone type 1.
        */
        @AuraEnabled public Object phoneTypeValue { get; set; }
        
        /** 
        * Description: Additional value for phone type 2.
        */
        @AuraEnabled public Object phoneTypeValue2 { get; set; }
        
        /** 
        * Description: Additional value for phone type 3.
        */
        @AuraEnabled public Object phoneTypeValue3 { get; set; }
        
        /** 
        * Description: CSS style associated with the column, if any.
        */
        @AuraEnabled public String style { get; set; }

        /**
        * Description: Constructor for initializing a `ColumnWrapper` object with specific values.
        * Handles type checks and formatting for various column types such as email, phone, etc.
        * 
        * @param value The value to be displayed in the column.
        * @param valueType The type of the value, e.g., STRING, EMAIL, PHONE.
        * @param label Optional label for the column.
        * @param isDescription Boolean indicating if the value is a description.
        * @param phoneTypeValue Additional value for phone type 1.
        * @param phoneTypeValue2 Additional value for phone type 2.
        * @param phoneTypeValue3 Additional value for phone type 3.
        */
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
                this.value=setformatEmail(value);
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
    


    /**
     * Description: Retrieves a map of field names and their types for the specified object.
     *
     * @param objectName The name of the object to retrieve fields and types for.
     * @return A map of field names to their respective types.
     */
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
    

    /**
     * Description: Retrieves a map of fields for the specified object.
     *
     * @param objectName The name of the object to retrieve fields for.
     * @return A map of field names to their respective Schema.SObjectField objects.
     */
    private static Map<String, Schema.SObjectField> getFields(String objectName){
        Map <String,Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType sobjType = gd.get(objectName);
        Schema.DescribeSObjectResult r = sobjType.getDescribe();
        return r.fields.getMap();
    }


    /**
     * Description: Formats a phone number for display.
     *
     * @param phoneNumber The phone number to format.
     * @return The formatted phone number.
     */
    private static Object setformatPhoneNumber(Object phoneNumber){
        string nonNumbers ='[^0-9]';
        Object formattedNumber;
        formattedNumber = 'tel:+1' + JSON.serialize(phoneNumber).replaceAll(nonNumbers, '');
        return formattedNumber;
    }

    /**
     * Description: Formats an email address for display.
     *
     * @param email The email address to format.
     * @return The formatted email address.
     */
    private static Object setformatEmail(Object email){
        if(!(JSON.serialize(email).contains('mailto:'))){
            return 'mailto:' + email;
        } else {
            return email;
        }
    }

}