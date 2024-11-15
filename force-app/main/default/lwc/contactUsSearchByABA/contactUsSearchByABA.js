import { LightningElement } from 'lwc';
import getContactDetails from '@salesforce/apex/ContactUsSearchController.getContactDetails';

export default class ContactUsSearchByABA extends LightningElement {

    showSpinner = false;

    errorMessage;
    code='';
    abaNumber;
    data;
    name;

    renderedCallback() {
        this.reframeSize();
    }

    handleSearch() {

        const regex = /^[a-zA-Z0-9!@#$%^&*()_+{}\[\]:;<>,.?~\\/\-=|"']{1,}$/;

        this.showSpinner = true;
        this.data = undefined;
        this.name = undefined;
        this.errorMessage = undefined;
        this.name = undefined;
        
        if (this.code == '' || this.code == undefined) {
            this.errorMessage = 'Please fill out this field';
            this.showSpinner = false;
        }
        else if (isNaN(this.code || regex.test(this.code)) || this.code.length > 9) {
            this.errorMessage = 'Please Specify a valid ABA Number';
            this.showSpinner = false;
        }
        else if (!isNaN(this.code) && this.code.length < 9) {
            this.errorMessage = 'Please Specify a valid ABA Number';
            this.showSpinner = false;
        }else {
            getContactDetails({ abaNumber: this.code }).then(result => {
                if (result.status == 'success') {
                    this.name = result.accountName;
                    //this.data = result;
                    this.abaNumber = this.code;
                    this.code = '';
                    this.data = JSON.parse(JSON.stringify(result).
                    replaceAll('&reg;', '<span style=\\"font-size:170%;vertical-align:middle;line-height: 0;\\">&reg;</span>'));
                }
                else if (result.status == 'error') {
                    this.errorMessage = result.message;
                }
                this.showSpinner = false;
            })
            .catch(error => {
                this.errorMessage = error.body.message;
                this.showSpinner = false;
            })
        }
    }
    
    handleChangeInput(event) {
        this.code = event.target.value;
    }

    reframeSize() {
        var applicationHeight = 0;
        if (this.template.querySelector(".iframeWindow") !== null) {
            var updatedHeight = this.template.querySelector(".iframeWindow").scrollHeight;
            if (!(updatedHeight === applicationHeight)) {
                applicationHeight = updatedHeight;
                window.parent.postMessage({ 'applicationFrameHeight': applicationHeight }, '*');
            }
        }
    }
}