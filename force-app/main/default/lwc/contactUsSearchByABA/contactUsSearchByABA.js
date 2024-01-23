import { LightningElement, track } from 'lwc';
import getContactDetails from '@salesforce/apex/ContactUsSearchController.getContactDetails';
export default class ContactUsSearchByABA extends LightningElement {
    show = false;
    spinnerShow = false;
    isError = false;
    errorMessage;
    abaNumber = '';
    code = '';
    searchData;

    renderedCallback() {
        this.reframeSize();
    }

    handleSearch() {
        console.log('@@@ this.' + this.code);
        const regex = /^[a-zA-Z0-9!@#$%^&*()_+{}\[\]:;<>,.?~\\/\-=|"']{1,}$/;
        if (this.code == '' || this.code.undefined) {
            this.isError = true;
            this.errorMessage = 'Please fill out this field';
            this.abaNumber = this.code;
            this.abaNumber = '';
            this.show = false;
        }
        else if (isNaN(this.code || regex.test(this.code)) || this.code.length > 9) {
            this.isError = true;
            this.errorMessage = 'Please Specify a valid ABA Number';
            this.abaNumber = this.code;
            this.abaNumber = '';
            this.show = false;
            console.log(this.code);
        }
        else if (!isNaN(this.code) && this.code.length < 9) {
            this.isError = true;
            this.errorMessage = 'Please Specify a valid ABA Number';
            this.abaNumber = this.code;
            this.abaNumber = '';
            this.show = false;
        }
        else {
            this.spinnerShow = true;
            getContactDetails({ abaNumber: this.code }).then(result => {
                if (result.status == 'success') {
                    this.name = result.accountName;
                    this.abaNumber = result.abaNumber;
                    this.show = true;
                    this.isError = false;
                    this.searchData = JSON.parse(JSON.stringify(result).
                        replaceAll('&reg;', '<span style=\\"font-size:170%;vertical-align:middle;line-height: 0;\\">&reg;</span>'));
                }
                else if (result.status == 'error') {
                    this.errorMessage = result.message;
                    this.abaNumber = '';
                    this.isError = true;
                    this.show = false;
                }
                this.spinnerShow = false;
            })
                .catch(error => {
                    this.isError = true;
                    this.errorMessage = error.body.message;
                    this.spinnerShow = false;
                    this.show = false;
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