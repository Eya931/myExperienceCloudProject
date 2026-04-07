import { LightningElement, track } from 'lwc';
import getPortalNews from '@salesforce/apex/PortalController.getPortalNews';

export default class PortalNews extends LightningElement {
    @track newsItems = [];

    connectedCallback() {
        getPortalNews()
            .then(data => {
                this.newsItems = Array.isArray(data) ? data.map(item => ({
                    ...item,
                    summary: item.summary || '',
                    cardClass: item.category === 'Job Offers' ? 'news-card is-job' : 'news-card is-company'
                })) : [];
            })
            .catch(() => {
                this.newsItems = [];
            });
    }

    get companyNews() {
        return this.newsItems.filter(item => item.category === 'Company News');
    }

    get jobNews() {
        return this.newsItems.filter(item => item.category === 'Job Offers');
    }

    get hasCompanyNews() {
        return this.companyNews.length > 0;
    }

    get hasJobNews() {
        return this.jobNews.length > 0;
    }
}