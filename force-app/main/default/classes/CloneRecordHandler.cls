public class CloneRecordHandler {
    //CloneRecordHandler.deleteCloneRecords(JSON.serialize(Trigger.OldMap), JSON.serialize(Trigger.New));
    @future
    public static void deleteCloneRecords(String jsonStringOldMap, String jsonStringNewList){
        Map<Id, ContactUsContact__c> oldMap = (Map<Id, ContactUsContact__c>) JSON.deserialize(jsonStringOldMap, Map<Id, ContactUsContact__c>.class);
        List<ContactUsContact__c> newContactUsContactList = (List<ContactUsContact__c>) JSON.deserialize(jsonStringNewList, List<ContactUsContact__c>.class);
        
        List<String> fields = new List<String>(ContactUsSearchController.getFields('ContactUsContact__c').keySet());
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
        fields.remove(fields.indexOf('lastmodifieddate'));
        fields.remove(fields.indexOf('systemmodstamp'));
        
        List<ContactUsContact__c> cloneContactUsContactToDelete = new List<ContactUsContact__c>();
        List<ContactUsContact__c> contactUsContactToUpdate = new List<ContactUsContact__c>();
        
        for(ContactUsContact__c con : newContactUsContactList) {
            ContactUsContact__c oldCon = oldMap.get(con.Id);
            
            if(oldCon.Status__c == 'Preview' && con.Status__c == 'Approved'
               && oldCon.Is_Clone__c && !con.Is_Clone__c
               && con.Clone_Source_Id__c != null){
                   
                   for(String field :fields){
                       if(oldCon.get(field) != con.get(field)){
                           oldCon.put(field, con.get(field));
                       }
                   }
                   
                   contactUsContactToUpdate.add(oldCon);
                   cloneContactUsContactToDelete.add(new ContactUsContact__c(Id = con.Id));
               }
        }
        
        if(!cloneContactUsContactToDelete.isEmpty()){
            delete cloneContactUsContactToDelete;
        }
        
        if(!contactUsContactToUpdate.isEmpty()){
            update contactUsContactToUpdate;
        }
    }
    
    public static void deleteCloneRecords2(String jsonStringUpdateList){ //String jsonStringDeleteList
        List<ContactUsContact__c> contactUsContactToUpdate = (List<ContactUsContact__c>) JSON.deserialize(jsonStringUpdateList, List<ContactUsContact__c>.class);
        //List<ContactUsContact__c> cloneContactUsContactToDelete = (List<ContactUsContact__c>) JSON.deserialize(jsonStringDeleteList, List<ContactUsContact__c>.class);
        
        /*if(!cloneContactUsContactToDelete.isEmpty()){
            delete cloneContactUsContactToDelete;
        }*/
        
        if(!contactUsContactToUpdate.isEmpty()){
            update contactUsContactToUpdate;
        }

    }
}