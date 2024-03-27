@isTest
public class ContactUsContactTriggerTest {

    @TestSetup
    static void setupData() {
        ContactUsContact__c contact1 = new ContactUsContact__c();
        contact1.Description__c = 'test1';
        contact1.Status__c = 'Approved';
        contact1.Category__c = 'Account Executive';
        //contact1.SubCategory__c = 'Foreign Check Processing';
        contact1.Email__c = 'ccc.coordinators@kc.frb.org';
        contact1.Phone__c = '(833) 377-7820';
        contact1.Status__c = 'Approved';
        contact1.Return_completed_original_docs_to__c = 'National Accounting Customer Support';
        insert contact1;
    }
    
    @isTest
    public static void testBeforeInsert_setIsCloneToTrue_whenUserCloneRecord(){
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c LIMIT 1];
        ContactUsContact__c cloneRecord = con.clone();
        cloneRecord.Status__c = 'Approved';
        
        Test.startTest();
        insert cloneRecord;
        Test.stopTest();
        
        cloneRecord = [SELECT Id, Is_Clone__c, Clone_Source_Id__c FROM ContactUsContact__c WHERE Id = :cloneRecord.Id];
        Assert.areEqual(true, cloneRecord.Is_Clone__c);
        Assert.areEqual(con.Id, cloneRecord.Clone_Source_Id__c);
    }
    
    @isTest
    public static void testBeforeInsert_itThrowError_whenUserTryToCloneAlreadyCloneRecord(){
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c LIMIT 1];
        
        ContactUsContact__c cloneRecord = con.clone();
        cloneRecord.Status__c = 'Approved';
        insert cloneRecord;
        
        cloneRecord = [SELECT Is_Clone__c, Clone_Source_Id__c FROM ContactUsContact__c WHERE Id = :cloneRecord.Id];
        String err = '';
        
        Test.startTest();
        try{
            ContactUsContact__c duplicateClone = cloneRecord.clone();
            insert duplicateClone;
        }catch(Exception e){
            err = e.getMessage();
        }
        Test.stopTest();
        
        Assert.areEqual(true, err.contains('You cannot clone of already clone record.'));
    }
    
     @isTest
    public static void testBeforeUpdate_itThrowError_whenUserTryToUpdateRecord(){
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c LIMIT 1];
        String err = '';
        
        Test.startTest();
        try{
            con.Description__c = 'test';
            update con;
        }catch(Exception e){
            err = e.getMessage();
        }
        Test.stopTest();
        
        Assert.areEqual(true, err.contains('You can only clone record to update the value and then submit for approval.'));
    }
    
    @isTest
    public static void testBeforeUpdate_itThrowError_whenUserTryToUpdateCloneRecordStatus(){
        ContactUsContact__c con = [SELECT Id FROM ContactUsContact__c LIMIT 1];
        ContactUsContact__c cloneRecord = con.clone();
        cloneRecord.Status__c = 'Approved';
        insert cloneRecord;
        
        // clone record submit for approval the status field set to 'Preview'
        Approval.ProcessSubmitRequest app = new Approval.ProcessSubmitRequest();
        app.setObjectId(cloneRecord.id);
        Approval.ProcessResult result = Approval.process(app);
        
        String err = '';
        
        Test.startTest();
        try{
            cloneRecord.Status__c = 'Approved';
            update cloneRecord;
        }catch(Exception e){
            err = e.getMessage();
        }
        Test.stopTest();
        
        Assert.areEqual(true, err.contains('You cannot update clone record status field. It will get update by approval process.'));
    }
    
     @isTest
    public static void testAfterUpdate_itDeleteCloneRecord_whenCloneRecordIsApproved(){
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
        
        // Submit the request for approval
        Approval.ProcessResult result2 =  Approval.process(req2);
                
        List<ContactUsContact__c> cloneRecordList = [SELECT Id FROM ContactUsContact__c WHERE Id = :cloneRecord.Id];
        System.assert(true, cloneRecordList.size() == 0);
        System.assert(true, result2.isSuccess());
    }
    
}