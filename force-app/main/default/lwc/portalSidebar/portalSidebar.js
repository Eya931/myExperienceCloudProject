import { LightningElement, api } from 'lwc';

export default class PortalSidebar extends LightningElement {
    @api items = [];
    @api activeSection = 'dashboard';
    @api userName = 'Candidate';
    @api collapsed = false;

    get sidebarClass() {
        return `portal-sidebar${this.collapsed ? ' is-collapsed' : ''}`;
    }

    get displayItems() {
        return (this.items || []).map(item => ({
            ...item,
            className: `menu-item${item.id === this.activeSection ? ' is-active' : ''}`
        }));
    }

    get userInitials() {
        const name = this.userName || 'Candidate';
        return name
            .split(' ')
            .filter(Boolean)
            .slice(0, 2)
            .map(part => part.charAt(0).toUpperCase())
            .join('');
    }

    handleSelect(event) {
        const section = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('navchange', {
                detail: { section },
                bubbles: true,
                composed: true
            })
        );
    }
}
