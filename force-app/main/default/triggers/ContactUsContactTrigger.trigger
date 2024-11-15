trigger ContactUsContactTrigger on ContactUsContact__c (before insert, before update, before delete, after insert, after update) { 
        switch on trigger.operationType{
        when BEFORE_INSERT{
            ContactUsContactTriggerHandler.onBeforeInsert(Trigger.new);
        }
        when AFTER_INSERT{
            ContactUsContactTriggerHandler.onAfterInsert(Trigger.new, Trigger.newMap);
        }
        when BEFORE_UPDATE{
            ContactUsContactTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.newMap, Trigger.old, Trigger.oldMap);
        }
        when AFTER_UPDATE{
            ContactUsContactTriggerHandler.onAfterUpdate(Trigger.new, Trigger.newMap, Trigger.old, Trigger.oldMap);
        }
    }
}