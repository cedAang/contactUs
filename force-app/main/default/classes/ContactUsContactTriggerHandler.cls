public class ContactUsContactTriggerHandler {

    public static void OnBeforeInsert(List<ContactUsContact__c> newList) {
        checkForCloneRecordOrThrowErrorIfFoundCloneOfCloneRecord(newList);
    }
    public static void OnAfterInsert(List<ContactUsContact__c> newList, Map<Id, ContactUsContact__c> newMap) {
        
    }
    public static void OnBeforeUpdate(List<ContactUsContact__c> newList, List<ContactUsContact__c> oldList, Map<Id, ContactUsContact__c> newMap, Map<Id, ContactUsContact__c> oldMap){
    	validateCloneRecord(newList, oldMap);
    }    
    public static void OnAfterUpdate(List<ContactUsContact__c> newList, List<ContactUsContact__c> oldList, Map<Id, ContactUsContact__c> newMap, Map<Id, ContactUsContact__c> oldMap){
        deleteCloneRecordAndUpdateOriginalRecord(newList, oldMap);
    }
    
    public static void checkForCloneRecordOrThrowErrorIfFoundCloneOfCloneRecord(List<ContactUsContact__c> newList){
        for(ContactUsContact__c con : newList) {
            if(con.isClone() && con.Status__c == 'Approved' && !con.Is_Clone__c ){
                con.Clone_Source_Id__c = con.getCloneSourceId();
                con.Is_Clone__c = true;
                con.Status__c = 'Preview';
            }else if(con.isClone() && con.Is_Clone__c){
                con.addError('You cannot clone of already clone record.');
            }
        }
    }
    
    public static void validateCloneRecord(List<ContactUsContact__c> newList, Map<Id, ContactUsContact__c> oldMap){
        for(ContactUsContact__c con : newList) {
            ContactUsContact__c oldCon = oldMap.get(con.Id);
            if(con.Status__c == 'Approved' && !oldCon.Is_Clone__c && !con.Is_Clone__c && !con.By_Pass_Validation__c){ //&& !con.Is_Approved__c
                con.addError('You can only clone record to update the value and then submit for approval.');
            }
            
            if(con.Is_Clone__c && oldCon.Status__c == 'Preview' && con.Status__c == 'Approved'){
                con.Status__c.addError('You cannot update clone record status field. It will get update by approval process.');
            }
            
            if(con.By_Pass_Validation__c){
                con.By_Pass_Validation__c = false;
            }
        }
    }
    
    public static void deleteCloneRecordAndUpdateOriginalRecord(List<ContactUsContact__c> newList, Map<Id, ContactUsContact__c> oldMap){
        Map<String, String> fieldTypeMap = getFieldsAndItsTypeMap('ContactUsContact__c');
        List<String> fields = new List<String>(fieldTypeMap.keySet());
        
        if(fields.contains('RecordTypeId')){
            fields.remove(fields.indexOf('RecordTypeId'));
        }
        if(fields.contains('OwnerId')){
            fields.remove(fields.indexOf('OwnerId'));
        }
        if(fields.contains('LastModifiedById')){
            fields.remove(fields.indexOf('LastModifiedById'));
        }
        if(fields.contains('CreatedById')){
            fields.remove(fields.indexOf('CreatedById'));
        }
        if(fields.contains('CreatedDate')){
            fields.remove(fields.indexOf('CreatedDate'));
        }
        if(fields.contains('LastModifiedDate')){
            fields.remove(fields.indexOf('LastModifiedDate'));
        }
        if(fields.contains('SystemModstamp')){
            fields.remove(fields.indexOf('SystemModstamp'));
        }
         
        List<ContactUsContact__c> cloneContactUsContactToDeleteList = new List<ContactUsContact__c>();
        List<ContactUsContact__c> contactUsContactToUpdateList = new List<ContactUsContact__c>();
        
        for(ContactUsContact__c con : newList) {
            ContactUsContact__c oldCon = oldMap.get(con.Id);
            
            if(oldCon.Status__c == 'Preview' && con.Status__c == 'Approved'
               && oldCon.Is_Clone__c && !con.Is_Clone__c
               && con.Clone_Source_Id__c != null){
                   
                   Boolean isValueChanged = false;
                   ContactUsContact__c contactUsContactToUpdate = new ContactUsContact__c();
                   
                   for(String field :fields){
                       contactUsContactToUpdate.put(field, convertToType(con.get(field), fieldTypeMap.get(field)));
                       isValueChanged = true;
                   }
                   
                   if(isValueChanged){
                       contactUsContactToUpdate.Id = con.Clone_Source_Id__c;
                       contactUsContactToUpdate.By_Pass_Validation__c = true;
                       contactUsContactToUpdateList.add(contactUsContactToUpdate);
                   }
                   
                   cloneContactUsContactToDeleteList.add(new ContactUsContact__c(Id = con.Id));
               }
        }
        
        
        if(!cloneContactUsContactToDeleteList.isEmpty()){
            deleteCloneRecords(JSON.serialize(cloneContactUsContactToDeleteList));
        }
        
        if(!contactUsContactToUpdateList.isEmpty()){
            update contactUsContactToUpdateList;
        }
    }
    
    public static Object convertToType(Object value, String fieldType){
        if(fieldType == 'ID' 
           || fieldType == 'REFERENCE' 
           || fieldType == 'STRING' 
           || fieldType == 'TEXTAREA' 
           || fieldType == 'PICKLIST' 
           || fieldType == 'EMAIL'
           || fieldType == 'URL'){
               return String.valueOf(value);
           }else if(fieldType == 'BOOLEAN'){
               return Boolean.valueOf(value);
           }else if(fieldType == 'DATETIME'){
               return DateTime.valueOf(value);
           }else if(fieldType == 'DATE'){
               return Date.valueOf(value);
           }else if(fieldType == 'PHONE'){
               return String.valueOf(value);
           }else if(fieldType == 'DOUBLE'){
               return Double.valueOf(value);
           }
        return null;
    }
    
    @Future
    public static void deleteCloneRecords(String jsonStringDeleteList){
        List<ContactUsContact__c> cloneContactUsContactToDeleteList = (List<ContactUsContact__c>) JSON.deserialize(jsonStringDeleteList, List<ContactUsContact__c>.class);
        delete cloneContactUsContactToDeleteList;
    }
    
    public static Map<String, String> getFieldsAndItsTypeMap(String objectName){
        Map<String, Schema.SObjectField> mapofField = getFields(objectName);
        Map<String, String> fieldTypeMap = new Map<String, String>();
        for(String fieldName : MapofField.keySet()) {
            Schema.SObjectField field = MapofField.get(fieldName);
            Schema.DescribeFieldResult F = field.getDescribe();
            if(F.isUpdateable()){
                fieldTypeMap.put(String.valueOf(field), String.valueOf(F.getType()));
            }
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