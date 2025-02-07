public with sharing class ContactUsContactTriggerHandler {
    
    // Constants to avoid typos in multiple usages
    @TestVisible private static final String STATUS_APPROVED = 'Approved';
    @TestVisible private static final String STATUS_PREVIEW = 'Preview';
    @TestVisible private static final String STATUS_REJECTED = 'Rejected';
    @TestVisible private static Boolean byPassTrigger = false;


    public static void onBeforeDelete( List<ContactUsContact__c> oldList){
        PreventDeleteRecord(oldList);
    } 

    public static void onBeforeInsert(List<ContactUsContact__c> newList) {
        checkForCloneRecordOrThrowErrorIfFoundDuplicateCloneRecord(newList);
    }

    public static void onBeforeUpdate(List<ContactUsContact__c> newList, Map<Id, ContactUsContact__c> newMap, List<ContactUsContact__c> oldList, Map<Id, ContactUsContact__c> oldMap){
    	validateCloneRecord(newList, oldMap);
    }    
    public static void onAfterUpdate(List<ContactUsContact__c> newList, Map<Id, ContactUsContact__c> newMap, List<ContactUsContact__c> oldList, Map<Id, ContactUsContact__c> oldMap){
        deleteCloneRecordAndUpdateOriginalRecord(newList, newMap, oldMap);
    }
    
    public static void PreventDeleteRecord(List<ContactUsContact__c> oldList){
        for(ContactUsContact__c con : oldList){
            if(con.Status__c == STATUS_APPROVED && !con.Delete_Record__c){
                con.addError('Record deletion in approved status is not allowed.');
            }
            
        }
    }

    public static void checkForCloneRecordOrThrowErrorIfFoundDuplicateCloneRecord(List<ContactUsContact__c> newList){

        for(ContactUsContact__c con : newList) {
            if(!con.IsCloned__c){
                if(ContactUsContactTriggerHandler.BypassTrigger){return;}
                con.Status__c = STATUS_PREVIEW;
                con.IsCloned__c = true;
                con.Clone_Source_Id__c = con.getCloneSourceId();
            }
             else if (con.IsCloned__c){
                con.addError('You cannot clone from a cloned record.');
            }                
        }
    }
    
    public static void validateCloneRecord(List<ContactUsContact__c> newList, Map<Id, ContactUsContact__c> oldMap){
        for(ContactUsContact__c con : newList) {
            ContactUsContact__c oldCon = oldMap.get(con.Id);
            //When user try to manual update a Approved record 
            if(con.Status__c == STATUS_APPROVED && oldCon.Status__c == STATUS_APPROVED && !oldCon.IsCloned__c && !con.IsCloned__c && con.Clone_Source_Id__c == null && !con.By_Pass_Validation__c){  //&& (cloneRecs == null || cloneRecs.isEmpty())
                con.addError('You should not edit original record but clone and update the value and then submit for approval (manual update)');
            }
            //When user try to manual update a Approved record by modifying the Status from Approved to Preview    
            else if((con.Status__c == STATUS_PREVIEW || con.Status__c == STATUS_REJECTED) && oldCon.Status__c == STATUS_APPROVED && !oldCon.IsCloned__c && !con.isClone() && !con.By_Pass_Validation__c ){ 
                con.addError('You should not edit original record but clone and update the value and then submit for approval (modifying the Status from Approved to Preview)');
            }
            // When Appover wants to manually approve
            else if(con.IsCloned__c && oldCon.Status__c == STATUS_PREVIEW && (con.Status__c == STATUS_APPROVED || con.Status__c == STATUS_REJECTED) && con.Clone_Source_Id__c != null  && !con.isClone()){
                con.Status__c.addError('You cannot update clone record status field. It will get update by approval process (manually approved).'); 
            }
            
            if(con.By_Pass_Validation__c){
                con.By_Pass_Validation__c = false;
            }
            
        }
    }
    
    public static void deleteCloneRecordAndUpdateOriginalRecord(List<ContactUsContact__c> newList, Map<Id, ContactUsContact__c> newMap, Map<Id, ContactUsContact__c> oldMap){
        List<ContactUsApprovalHistory__c> approvalHistoryListToInsert = new List<ContactUsApprovalHistory__c>();

        List<ContactUsContact__c> cloneContactUsContactListToDelete = new List<ContactUsContact__c>();

        List<ContactUsContact__c> contactUsContactListToUpdate = new List<ContactUsContact__c>();

        Map<String, String> cloneOriginalRecordMap = new Map<String, String>();

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
        
        for(ContactUsContact__c con : newList) {
            ContactUsContact__c oldCon = oldMap.get(con.Id);
            if(!con.IsCloned__c && oldCon.Status__c == STATUS_PREVIEW && (con.Status__c == STATUS_APPROVED || con.Status__c == STATUS_REJECTED) && con.OwnerId == con.LastModifiedById){
                //con.Status__c.addError('You cannot be a Submitter/Admin and Approver of a record at same time.');
            }
            
            if(oldCon.Status__c == STATUS_PREVIEW && (con.Status__c == STATUS_APPROVED || con.Status__c == STATUS_REJECTED) && oldCon.IsCloned__c && !con.IsCloned__c && con.Clone_Source_Id__c != null){
                cloneOriginalRecordMap.put(con.Id, con.Clone_Source_Id__c);
                
                ContactUsContact__c contactUsContactToUpdate = new ContactUsContact__c();
                contactUsContactToUpdate.Id = con.Clone_Source_Id__c;
                
                // copying all values from clone to original record
                for(String field :fields){
                    System.debug('field: '+field+' '+con.get(field.trim()));
                    contactUsContactToUpdate.put(field, convertToType(con.get(field.trim()), fieldTypeMap.get(field.trim())));
                }
                contactUsContactToUpdate.Clone_Source_Id__c = null;
                contactUsContactToUpdate.By_Pass_Validation__c = true; 
                
                if(con.Status__c != STATUS_REJECTED){
                    contactUsContactListToUpdate.add(contactUsContactToUpdate);
                    }
                cloneContactUsContactListToDelete.add(new ContactUsContact__c(Id = con.Id, Clone_Source_Id__c = con.Clone_Source_Id__c));
            }
        }
        if(ProcessInstance.SObjectType.getDescribe().isAccessible()){
        List<ProcessInstance> processInstanceList = [SELECT LastActor.name, TargetObjectId, TargetObject.Name, Status, SubmittedBy.Name, CreatedbyId, CompletedDate,
                                                     (SELECT Id, ProcessInstanceId, Comments FROM Steps ORDER BY CreatedDate DESC LIMIT 1)  
                                                     FROM ProcessInstance 
                                                     WHERE TargetObjectId IN :cloneOriginalRecordMap.keySet() WITH USER_MODE]; ////Status in('Approved','Rejected')
                
        for(ProcessInstance pi :processInstanceList){
            ContactUsApprovalHistory__c conhist =  new ContactUsApprovalHistory__c();
            conhist.Name = cloneOriginalRecordMap.get(pi.TargetObjectId);
            conhist.TargetObject__c = cloneOriginalRecordMap.get(pi.TargetObjectId);
            conhist.Status__c= pi.Status;
            conhist.Submitter__c = pi.SubmittedBy.Name;
            conhist.Approver__c = pi.LastActor.name;
            conhist.Date__c = pi.CompletedDate;
            for(ProcessInstanceStep pis : pi.Steps){
                if(pi.Id == pis.ProcessInstanceId){
                    conhist.Comments__c = pis.Comments;
                }
            }
            approvalHistoryListToInsert.add(conhist);
        }
    }
         
        if(!approvalHistoryListToInsert.isEmpty()){
            if(Schema.SObjectType.ContactUsApprovalHistory__c.isCreateable()){
                insert as user approvalHistoryListToInsert; 
            }
            
        }
       
        if(!cloneContactUsContactListToDelete.isEmpty()){
            List<RecordRedirectEvent__e> eventsToPublish = new List<RecordRedirectEvent__e>();
            eventsToPublish.add(new RecordRedirectEvent__e(Record_Id__c = cloneContactUsContactListToDelete[0].Clone_Source_Id__c));           
            if (!eventsToPublish.isEmpty()) {
                EventBus.publish(eventsToPublish);
            }
            deleteCloneRecords(JSON.serialize(cloneContactUsContactListToDelete));
        }
        
        if(!contactUsContactListToUpdate.isEmpty()){
            if(Schema.SObjectType.ContactUsContact__c.isUpdateable()){
                update as user contactUsContactListToUpdate;
            }
            
        }
       
    }
    
    @Future
    public static void deleteCloneRecords(String jsonString){
        List<ContactUsContact__c> cloneContactUsContactTListoDelete = (List<ContactUsContact__c>) JSON.deserialize(jsonString, List<ContactUsContact__c>.class);
        if(Schema.SObjectType.ContactUsContact__c.isUpdateable()){
            delete as user cloneContactUsContactTListoDelete;
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
        
    public static Map<String, String> getFieldsAndItsTypeMap(String objectName){
        Map<String, Schema.SObjectField> mapofField = getFields(objectName);
        Map<String, String> fieldTypeMap = new Map<String, String>();
        
        for(String fieldName : MapofField.keySet()) {
            Schema.SObjectField field = MapofField.get(fieldName);
            Schema.DescribeFieldResult f = field.getDescribe();
            if(F.isUpdateable()){
                fieldTypeMap.put(String.valueOf(field), String.valueOf(F.getType()));
            }
        }
        return fieldTypeMap;
    }
    
     public static Map<String, Schema.SObjectField> getFields(String objectName){
        Map <String,Schema.SObjectType> gd = Schema.getGlobalDescribe();   
        Schema.SObjectType sobjType = gd.get(objectName);
        Schema.DescribeSObjectResult desSObjectresult = sobjType.getDescribe();
        return desSObjectresult.fields.getMap();
    }
    
}