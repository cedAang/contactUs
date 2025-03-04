trigger OrderEventTrigger on Order_Event__e (after insert) {

    switch on trigger.operationType{
        when AFTER_INSERT{
            
        }  

    } 

}