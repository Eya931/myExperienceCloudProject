import { LightningElement, track } from 'lwc';
import getJobs from '@salesforce/apex/PortalController.getOpenJobs';

const ALL_JOBS = [
    { id:'1', dept:'Engineering', title:'Senior Frontend Engineer', type:'Full-time', location:'Remote',       exp:'5+ yrs', salary:'$120k – $160k', posted:'2 days ago'  },
    { id:'2', dept:'Design',      title:'Product Designer',         type:'Full-time', location:'Hybrid Tunis', exp:'3+ yrs', salary:'$90k – $120k',  posted:'3 days ago'  },
    { id:'3', dept:'Product',     title:'Product Manager — Growth', type:'Full-time', location:'Remote',       exp:'4+ yrs', salary:'$110k – $145k', posted:'5 days ago'  },
    { id:'4', dept:'Engineering', title:'Backend Engineer — Infra', type:'Full-time', location:'Remote',       exp:'4+ yrs', salary:'$130k – $170k', posted:'1 week ago'  },
    { id:'5', dept:'Marketing',   title:'Head of Content',          type:'Full-time', location:'Hybrid Paris', exp:'6+ yrs', salary:'$95k – $125k',  posted:'1 week ago'  },
    { id:'6', dept:'People Ops',  title:'People Operations Lead',   type:'Full-time', location:'Remote',       exp:'4+ yrs', salary:'$85k – $110k',  posted:'2 weeks ago' },
];

export default class PortalSearchJob extends LightningElement {
    @track searchTerm = '';
    @track locationTerm = '';
    @track typeFilter = '';
    @track activeDept = 'All Jobs';
    @track jobs = ALL_JOBS;

    get departments() { return ['All Jobs', 'Engineering', 'Design', 'Product', 'Marketing', 'People Ops']; }

    get departmentFilters() {
        return this.departments.map((dept) => ({
            name: dept,
            cssClass: `filter-pill${dept === this.activeDept ? ' active' : ''}`
        }));
    }

    get filteredJobs() {
        return this.jobs.filter(j => {
            const matchSearch = !this.searchTerm || j.title.toLowerCase().includes(this.searchTerm.toLowerCase());
            const matchLocation = !this.locationTerm || j.location.toLowerCase().includes(this.locationTerm.toLowerCase());
            const matchType = !this.typeFilter || j.type === this.typeFilter;
            const matchDept = this.activeDept === 'All Jobs' || j.dept === this.activeDept;
            return matchSearch && matchLocation && matchType && matchDept;
        });
    }

    handleSearch(e)   { this.searchTerm = e.target.value; }
    handleLocation(e) { this.locationTerm = e.target.value; }
    handleType(e)     { this.typeFilter = e.target.value; }
    filterByDept(e)   { this.activeDept = e.currentTarget.dataset.dept; }
    search()          { /* reactive */ }

    applyNow(e) {
        const id = e.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('applyjob', { detail: id, bubbles: true, composed: true }));
    }

    connectedCallback() {
        getJobs().then(data => { if (data && data.length) this.jobs = data; }).catch(() => {});
    }
}