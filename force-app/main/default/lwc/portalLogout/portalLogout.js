import { LightningElement } from 'lwc';

export default class PortalLogout extends LightningElement {
    static LOGIN_URL = '/Core/login';

    handleLogout() {
        const retUrl = encodeURIComponent(PortalLogout.LOGIN_URL);
        globalThis.location.href = `/secur/logout.jsp?retUrl=${retUrl}`;
    }
}
