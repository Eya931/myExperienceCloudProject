import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import isGuestUser from '@salesforce/user/isGuest';

export default class JobFooter extends NavigationMixin(LightningElement) {
    isGuest = isGuestUser;

    handleLogin() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Login' }
        });
    }

    handleRegister() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'SelfRegister' }
        });
    }

    handleLogout() {
        const sitePrefix = globalThis.location.pathname.replace(/\/s\/.*/i, '');
        globalThis.location.href = `${sitePrefix}/secur/logout.jsp`;
    }
}
