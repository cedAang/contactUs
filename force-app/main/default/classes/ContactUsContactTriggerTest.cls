/**
 * Description: This test class validates the functionality of the ContactUsContactTrigger.
 * It ensures that the trigger behaves as expected for various scenarios, including cloning, 
 * updating, and deleting ContactUsContact__c records. The test cases cover:
 * 
 * - Setting up test data for ContactUsContact__c records.
 * - Validating that cloning a record correctly marks it as cloned.
 * - Ensuring that cloning an already cloned record throws an error.
 * - Preventing updates on original records.
 * - Restricting updates to the status field of cloned records.
 * - Verifying that approved clone records are deleted after approval.
 * - Preventing deletion of approved records.
 * 
 * Each test follows Salesforce best practices, including the use of 
 * @TestSetup for reusable data, Test.startTest()/Test.stopTest() blocks 
 * for governor limit isolation, and assertions for expected behavior.
 */


 @isTest
public class ContactUsContactTriggerTest {
    
    /**
     * Description: Sets up test data for ContactUsContact__c records.
     * This method creates a sample ContactUsContact__c record to be used 
     * across test cases.
     *
     * @param N/A
     * @return N/A
     */
    @TestSetup
    static void setupData() {
        ContactUsContactTriggerHandler.BypassTrigger = true;
        ContactUsContact__c con = new ContactUsContact__c();
        con.Description__c = 'test1';
        con.Status__c = 'Approved';
        con.Category__c = 'Account Executive';
        con.Email__c = 'ccc.coordinators@kc.frb.org';
        con.Phone__c = '(833) 377-7820';
        con.Return_completed_original_docs_to__c = 'National Accounting Customer Support';
        con.Delete_Record__c = false;
        insert con;
    }
    
    /**
     * Description: Validates that when a record is cloned, the IsCloned__c 
     * field is set to true.
     *
     * @param N/A
     * @return N/A
     */
    @isTest
    public static void testBeforeInsertSetIsCloneToTrueWhenUserCloneRecord() {
        ContactUsContactTriggerHandler.BypassTrigger = false;
        ContactUsContact__c con = [SELECT Id, IsCloned__c FROM ContactUsContact__c LIMIT 1];
        ContactUsContact__c cloneRecord = con.clone(false, true);
        
        Test.startTest();
        insert cloneRecord;
        Test.stopTest();
        
        cloneRecord = [SELECT Id, IsCloned__c FROM ContactUsContact__c WHERE Id = :cloneRecord.Id];
        
        Assert.areEqual(true, cloneRecord.IsCloned__c, 'IsClone__c should be true when a record is cloned.');
    }
    
    /**
     * Description: Ensures that cloning an already cloned record throws an error.
     *
     * @param N/A
     * @return N/A
     */
    @isTest
    public static void testBeforeInsertItThrowErrorWhenUserTryToCloneAlreadyCloneRecord() {
        ContactUsContactTriggerHandler.BypassTrigger = false;
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c WHERE Status__c = 'Approved' LIMIT 1];
        
        ContactUsContact__c cloneRecord = con.clone();
        cloneRecord.Status__c = 'Approved';
        insert cloneRecord;
        
        cloneRecord = [SELECT IsCloned__c FROM ContactUsContact__c WHERE Id = :cloneRecord.Id];
        
        Test.startTest();
        try {
            ContactUsContact__c duplicateClone = cloneRecord.clone();
            insert duplicateClone;
            Assert.fail('DmlException Expected');
        } catch (Exception e) {
            Assert.areEqual(true, e.getMessage().contains('You cannot clone from a cloned record.'));
        }
        Test.stopTest();       
    }
    
    /**
     * Description: Ensures that updating an original ContactUsContact__c record 
     * throws an error.
     *
     * @param N/A
     * @return N/A
     */
    @isTest
    public static void testBeforeUpdateItThrowErrorWhenUserTryToUpdateRecord() {
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c LIMIT 1];
        
        Test.startTest();
        try {
            con.Description__c = 'test';
            update con;
            Assert.fail('DmlException Expected');
        } catch (Exception e) {
            Assert.areEqual(true, e.getMessage().contains('You should not edit original record but clone and update the value and then submit for approval'));
        }
        Test.stopTest();
    }
    
    /**
     * Description: Ensures that updating the status field of a cloned record 
     * throws an error.
     *
     * @param N/A
     * @return N/A
     */
    @isTest
    public static void testBeforeUpdateItThrowErrorWhenUserTryToUpdateCloneRecordStatus() {
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c WHERE Status__c = 'Approved' LIMIT 1];
        ContactUsContact__c approvalRecord = new ContactUsContact__c(Status__c = 'Preview', Clone_Source_Id__c = con.Id);
        insert approvalRecord;
        
        Approval.ProcessSubmitRequest app = new Approval.ProcessSubmitRequest();
        app.setObjectId(approvalRecord.id);
        Approval.ProcessResult result = Approval.process(app);
        
        Test.startTest();
        try {
            approvalRecord.Status__c = 'Approved';
            update approvalRecord;
            Assert.fail('DmlException Expected');
        } catch (Exception e) {
            Assert.areEqual(true, e.getMessage().contains('You cannot update clone record status field. It will get updated by approval process (manually approved).'));
        }
        Test.stopTest();
    }
    
    /**
     * Description: Ensures that a cloned record is deleted after it gets approved.
     *
     * @param N/A
     * @return N/A
     */
    @isTest
    public static void testAfterUpdateItDeleteCloneRecordWhenCloneRecordIsApproved() {
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
        
        List<RecordRedirectEvent__e> eventsToPublish = new List<RecordRedirectEvent__e>();
        eventsToPublish.add(new RecordRedirectEvent__e(Record_Id__c = con.Id));
        
        System.assert(!eventsToPublish.isEmpty(), 'Events list should not be empty');

        Test.startTest();
        
        Approval.ProcessResult result2 = Approval.process(req2);
        
        EventBus.publish(eventsToPublish);
        
        Test.stopTest();
        
        List<ContactUsContact__c> contactUsContacts = [SELECT Id FROM ContactUsContact__c];
        Assert.areEqual(1, contactUsContacts.size());
        
        System.debug('Platform Event published successfully');
    }
    
    /**
     * Description: Ensures that an approved record cannot be deleted.
     *
     * @param N/A
     * @return N/A
     */
    @isTest
    public static void testPreventRecordDeletion() {
        ContactUsContact__c con = [SELECT Id, IsCloned__c FROM ContactUsContact__c LIMIT 1];
        
        Test.startTest();
        try {
            delete con; 
            Assert.fail('DmlException Expected'); 
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Record deletion in approved status is not allowed.'), 'Unexpected error message: ' + e.getMessage());
        }
        Test.stopTest();
    }     
}