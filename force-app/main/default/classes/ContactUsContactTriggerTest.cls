@isTest
public class ContactUsContactTriggerTest {
    
    @TestSetup
    static void setupData() {
        ContactUsContactTriggerHandler.BypassTrigger =true;
        ContactUsContact__c con = new ContactUsContact__c();
        con.Description__c = 'test1';
        con.Status__c = 'Approved';
        con.Category__c = 'Account Executive';
        //con.SubCategory__c = 'Foreign Check Processing';
        con.Email__c = 'ccc.coordinators@kc.frb.org';
        con.Phone__c = '(833) 377-7820';
        con.Status__c = 'Approved';
        con.Return_completed_original_docs_to__c = 'National Accounting Customer Support';
        con.Delete_Record__c = false;
        insert con;
    }
    
    @isTest
    public static void testBeforeInsertSetIsCloneToTrueWhenUserCloneRecord(){
        ContactUsContactTriggerHandler.BypassTrigger =false;
        ContactUsContact__c con = [SELECT Id,IsCloned__c FROM ContactUsContact__c LIMIT 1];
        ContactUsContact__c cloneRecord = con.clone(false, true);
        
        Test.startTest();
        insert cloneRecord;
        Test.stopTest();
        
        cloneRecord = [SELECT Id, IsCloned__c FROM ContactUsContact__c WHERE Id = :cloneRecord.Id];
        
        Assert.areEqual(true, cloneRecord.IsCloned__c,'IsClone__c = true');
    }
    
    @isTest
    public static void testBeforeInsertItThrowErrorWhenUserTryToCloneAlreadyCloneRecord(){
        ContactUsContactTriggerHandler.BypassTrigger =false;
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c WHERE Status__c = 'Approved' LIMIT 1];
        
        ContactUsContact__c cloneRecord = con.clone();
        cloneRecord.Status__c = 'Approved';
        insert cloneRecord;
        
        cloneRecord = [SELECT IsCloned__c FROM ContactUsContact__c WHERE Id = :cloneRecord.Id];
        
        Test.startTest();
        try{
            ContactUsContact__c duplicateClone = cloneRecord.clone();
            insert duplicateClone;
            Assert.fail('DmlException Expected');
        }catch(Exception e){
            Assert.areEqual(true, e.getMessage().contains('You cannot clone from a cloned record.'));
        }
        Test.stopTest();       
    }
    
    @isTest
    public static void testBeforeUpdateItThrowErrorWhenUserTryToUpdateRecord(){
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c LIMIT 1];
        
        Test.startTest();
        try{
            con.Description__c = 'test';
            update con;
    		Assert.fail('DmlException Expected');
        }catch(Exception e){
            Assert.areEqual(true, e.getMessage().contains('You should not edit original record but clone and update the value and then submit for approval'));
        }
        Test.stopTest();
    }
    
    @isTest
    public static void testBeforeUpdateItThrowErrorWhenUserTryToUpdateCloneRecordStatus(){
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c WHERE Status__c = 'Approved' LIMIT 1];
        ContactUsContact__c approvalRecord = new ContactUsContact__c (Status__c ='Preview',Clone_Source_Id__c = con.Id);
        insert approvalRecord;
        
        // clone record submit for approval the status field set to 'Preview'
        Approval.ProcessSubmitRequest app = new Approval.ProcessSubmitRequest();
        app.setObjectId(approvalRecord.id);
        Approval.ProcessResult result = Approval.process(app);
        
        Test.startTest();
        try{
            approvalRecord.Status__c = 'Approved';
            update approvalRecord;
    		Assert.fail('DmlException Expected');
        }catch(Exception e){
            Assert.areEqual(true, e.getMessage().contains('You cannot update clone record status field. It will get update by approval process (manually approved).'));
        }
        Test.stopTest();
    }
    
    @isTest
    public static void testAfterUpdateItDeleteCloneRecordWhenCloneRecordIsApproved(){
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c LIMIT 1];
        ContactUsContact__c cloneRecord = con.clone();
        cloneRecord.Status__c = 'Approved';
        insert cloneRecord;
        
        Approval.ProcessSubmitRequest app = new Approval.ProcessSubmitRequest();
        app.setObjectId(cloneRecord.id);
        Approval.ProcessResult result = Approval.process(app);
        
        List<Id> newWorkItemIds = result.getNewWorkitemIds();
        
        Approval.ProcessWorkitemRequest req2 = new Approval.ProcessWorkitemRequest();
        req2.setComments('Approving request.');
        req2.setAction('Approve');
        req2.setNextApproverIds(new Id[] {UserInfo.getUserId()});
        req2.setWorkitemId(newWorkItemIds.get(0));
        
        // Prepare the Platform Event List
        List<RecordRedirectEvent__e> eventsToPublish = new List<RecordRedirectEvent__e>();
        eventsToPublish.add(new RecordRedirectEvent__e(Record_Id__c = con.Id));
        
        // Ensure the list is not empty
        System.assert(!eventsToPublish.isEmpty(), 'Events list should not be empty');

        Test.startTest();
        
        // Submit the request for approval
        Approval.ProcessResult result2 =  Approval.process(req2);
        
        // Publish the event
        EventBus.publish(eventsToPublish);
        
        Test.stopTest();
        
        List<ContactUsContact__c> contactUsContacts = [SELECT Id FROM ContactUsContact__c];
        Assert.areEqual(1, contactUsContacts.size());
        
        // Since Platform Events are asynchronous, we cannot query them directly
        System.debug('Platform Event published successfully');
    }
    
    @isTest
    public static void testPreventRecordDeletion(){
        ContactUsContact__c con = [SELECT Id,IsCloned__c FROM ContactUsContact__c LIMIT 1];
        
        Test.startTest();
        try {
            delete con; 
            Assert.fail('DmlException Expected'); 
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Record deletion in approved status is not allowed.'),'Unexpected error message: ' + e.getMessage());
        }
        Test.stopTest();
    }     
    
}