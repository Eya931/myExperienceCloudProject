import { LightningElement } from 'lwc';
export default class PortalNews extends LightningElement {
    get newsItems() {
        return [
            { id:'1', imgClass:'nc-img nc-img-1', category:'Career Tips',   title:'How to Ace a Technical Interview in 2025',           date:'Mar 14, 2025' },
            { id:'2', imgClass:'nc-img nc-img-2', category:'Salary Guide',  title:'Frontend Engineer Salaries in 2025 — What to Expect', date:'Mar 10, 2025' },
            { id:'3', imgClass:'nc-img nc-img-3', category:'Industry News', title:'Top 10 Companies Hiring Remote Engineers This Month',  date:'Mar 7, 2025'  },
            { id:'4', imgClass:'nc-img nc-img-4', category:'Trends',        title:'AI Tools Every Developer Should Know in 2025',        date:'Mar 3, 2025'  },
            { id:'5', imgClass:'nc-img nc-img-5', category:'Career Growth', title:'From Junior to Senior: A Roadmap for Engineers',      date:'Feb 28, 2025' },
            { id:'6', imgClass:'nc-img nc-img-6', category:'Remote Work',   title:'Best Practices for Remote Collaboration in Tech',     date:'Feb 24, 2025' },
        ];
    }
}