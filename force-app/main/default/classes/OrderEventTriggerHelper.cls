public with sharing class OrderEventTriggerHelper {
    


    public static void onAfterInsert (List<Order_Event__e> newOrderEvent){
        List<Order_Event__e>  shippedOrders = new List<Order_Event__e>();
        for( Order_Event__e evnt : newOrderEvent){
            if(evnt.Has_Shipped__c == true){
                evnt.add(shippedOrders);
            }
            CreateOrderEventTasks(shippedOrders);
        }

    }
    private static void createOrderEventTasks (List<Order_Event__e> shippedOrders){
        string error = '';
        try {
            if(shippedOrders.sized() > 0){
                for(Order_Event__e ordEvnt : shippedOrders){
                    task tk = new task();
                    tk.Priority = 'Medium';
                    tk.Subject = 'Follow up on shipped order 10';
                    tk.OwnerId = ordEvnt.CreatedById;
                }
                if (Schema.sObjectType.task.isCreatable()) {
                    insert tk ;
                }else {
                    return null;
                }
                
            }else{
                error =' No order Shipped';
            }   
        } catch (Exception e) {

            System.debug('The following exception has occurred: ' + e.getMessage());
        }
    }

}