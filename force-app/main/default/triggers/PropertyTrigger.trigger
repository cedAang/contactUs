trigger PropertyTrigger on Property__c(before insert , before update, before delete, after insert, after update, after delete, after undelete){
    switch on trigger.operationType{

        when BEFORE_INSERT{
            PropertyTriggerhelper.onBeforeInsert(Trigger.new);
        }
        when BEFORE_UPDATE{
            PropertyTriggerhelper.onBeforeInsert(Trigger.newMap,Trigger.oldMap);
        }
        when BEFORE_DELETE{}
        when AFTER_INSERT{}
        when AFTER_UPDATE{}
        when AFTER_DELETE{}
        when AFTER_UNDELETE{}    
    }
}