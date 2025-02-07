public with sharing class PropertyTriggerhelper {
    
    
    public static void onBeforeInsert( List<Property__c> newList) {

        
        List< Protery__c > newProp = new List<Property__c> ();


        for(Propery__c prop : newList){
            if(prop.Agent__c != null){

            }

        }

    }
    public static void  onBeforeUpdate( Map<Id , Proterty__c> newMap , Map<Id, Property__c> oldMap){

    }
}