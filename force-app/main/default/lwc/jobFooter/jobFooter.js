import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import isGuestUser from '@salesforce/user/isGuest';

export default class JobFooter extends NavigationMixin(LightningElement) {
    isGuest = isGuestUser;
}
