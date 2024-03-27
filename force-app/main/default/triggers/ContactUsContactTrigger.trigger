trigger ContactUsContactTrigger on ContactUsContact__c (before insert, before update, before delete, after insert, after update) {
    
    System.TriggerOperation triggerEvent = trigger.operationType;
    
    switch on triggerEvent {
        when BEFORE_INSERT {
            ContactUsContactTriggerHandler.OnBeforeInsert(Trigger.New);
        }
        when AFTER_INSERT {
            ContactUsContactTriggerHandler.OnAfterInsert(Trigger.New, Trigger.NewMap);
        }
        when BEFORE_UPDATE {
            ContactUsContactTriggerHandler.OnBeforeUpdate(Trigger.New, Trigger.Old, Trigger.NewMap, Trigger.OldMap);
        }
        when AFTER_UPDATE{
            ContactUsContactTriggerHandler.OnAfterUpdate(Trigger.New, Trigger.Old, Trigger.NewMap, Trigger.OldMap);
        }
    }    
    
}