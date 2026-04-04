import { LightningElement, track } from 'lwc';

// ─── Static FAQ data ──────────────────────────────────────────────────────────
// In a real implementation replace this with a wire adapter or @api property
// e.g. @wire(getFaqItems) or pass via @api faqs from a parent component.
const FAQ_DATA = [
    {
        id: 'faq-1',
        category: 'candidates',
        question: 'How do I create a candidate profile on TalentBridge?',
        answer: 'Creating a profile is free and takes less than 5 minutes. Click "Get Started", fill in your professional details, upload your CV, and set your job preferences. Our smart matching engine will immediately start surfacing relevant opportunities tailored to your skills and experience.',
        link: { label: 'Create your profile', url: '/register' }
    },
    {
        id: 'faq-2',
        category: 'candidates',
        question: 'Is TalentBridge free for job seekers?',
        answer: 'Yes — TalentBridge is completely free for job seekers. You can create a profile, browse all job listings, apply to positions, and track your applications at no cost. Premium features like advanced analytics and priority placement are available as optional upgrades.',
        link: null
    },
    {
        id: 'faq-3',
        category: 'candidates',
        question: 'What types of roles are available on the platform?',
        answer: 'We specialise in SAP, Salesforce, Microsoft Dynamics 365, .NET / Full Stack, Data & AI, and Cloud roles across contract, full-time, and remote positions. We work with consulting firms, SIs, and enterprise clients across Europe and North America.',
        link: { label: 'Browse all jobs', url: '/jobs' }
    },
    {
        id: 'faq-4',
        category: 'candidates',
        question: 'How does the coding challenge work in the candidate portal?',
        answer: 'When an employer requests a technical assessment, you will receive an email invitation and a notification in your candidate portal. The challenge is locked until the window opens. Once you begin, you have a set time (usually 90 minutes) to solve the problems. Results are shared directly with the recruiter after submission.',
        link: null
    },
    {
        id: 'faq-5',
        category: 'candidates',
        question: 'How long does it take to hear back after applying?',
        answer: 'Response times vary by employer, but our platform sends you a real-time notification as soon as your application status changes. On average, candidates receive a first response within 5 to 7 business days. You can track every stage of every application from your candidate portal dashboard.',
        link: { label: 'Go to your portal', url: '/portal' }
    },
    {
        id: 'faq-6',
        category: 'employers',
        question: 'How can employers post a job on TalentBridge?',
        answer: 'Employers can register a company account, complete their profile, and post a job listing in minutes. Each listing supports rich descriptions, required skills, contract type, salary range, and location. You can also access our CV database and reach out to passive candidates directly.',
        link: { label: 'Post a job', url: '/post-job' }
    },
    {
        id: 'faq-7',
        category: 'employers',
        question: 'What pricing plans are available for employers?',
        answer: 'We offer three plans: Starter (up to 3 active listings), Growth (unlimited listings + CV database access), and Enterprise (custom pricing, dedicated account manager, and API access). All plans include a 14-day free trial with no credit card required.',
        link: { label: 'View pricing', url: '/pricing' }
    },
    {
        id: 'faq-8',
        category: 'platform',
        question: 'Is my data secure on TalentBridge?',
        answer: 'Absolutely. TalentBridge is built on Salesforce Experience Cloud and follows GDPR guidelines. Your personal data is encrypted at rest and in transit. You control exactly which employers can view your profile, and you can delete your account and all associated data at any time from your settings.',
        link: { label: 'Read our privacy policy', url: '/privacy' }
    },
    {
        id: 'faq-9',
        category: 'platform',
        question: 'Can I apply to multiple jobs simultaneously?',
        answer: 'Yes. There is no limit on the number of simultaneous applications. Your Opportunity Tracker in the candidate portal gives you a visual pipeline for each application so you can monitor progress, upcoming interviews, and assessment deadlines across all roles at once.',
        link: null
    }
];

const CATEGORIES = [
    { value: 'all',        label: 'All Questions' },
    { value: 'candidates', label: 'For Candidates' },
    { value: 'employers',  label: 'For Employers'  },
    { value: 'platform',   label: 'Platform & Security' }
];

export default class TalentBridgeFaq extends LightningElement {

    // ── Reactive state ────────────────────────────────────────────────────────
    @track _faqs          = FAQ_DATA.map(f => ({ ...f, isOpen: f.id === 'faq-1' }));
    @track searchTerm     = '';
    @track activeCategory = 'all';

    // ── Getters ───────────────────────────────────────────────────────────────

    get categories() {
        return CATEGORIES.map(cat => ({
            ...cat,
            cssClass: 'cat-btn' + (cat.value === this.activeCategory ? ' cat-btn--active' : '')
        }));
    }

    get filteredFaqs() {
        const term = this.searchTerm.toLowerCase().trim();
        const cat  = this.activeCategory;

        return this._faqs
            .filter(faq => {
                const matchesCat    = cat === 'all' || faq.category === cat;
                const matchesSearch = !term ||
                    faq.question.toLowerCase().includes(term) ||
                    faq.answer.toLowerCase().includes(term);
                return matchesCat && matchesSearch;
            })
            .map(faq => ({
                ...faq,
                itemClass   : 'faq-item' + (faq.isOpen ? ' faq-item--open' : ''),
                answerClass : 'faq-a' + (faq.isOpen ? ' faq-a--open' : '')
            }));
    }

    get filteredCount() {
        return this.filteredFaqs.length;
    }

    get hasResults() {
        return this.filteredFaqs.length > 0;
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        this._faqs = this._faqs.map(faq => ({
            ...faq,
            // Accordion: close all, open clicked (toggle if already open)
            isOpen: faq.id === id ? !faq.isOpen : false
        }));
    }

    handleKeydown(event) {
        // Accessibility: allow Enter or Space to toggle
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleToggle(event);
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        // Collapse all items when searching so results feel fresh
        this._faqs = this._faqs.map(faq => ({ ...faq, isOpen: false }));
    }

    clearSearch() {
        this.searchTerm = '';
        this._faqs = this._faqs.map((faq, i) => ({ ...faq, isOpen: i === 0 }));
    }

    handleCategoryClick(event) {
        this.activeCategory = event.currentTarget.dataset.value;
        // Collapse all when switching category
        this._faqs = this._faqs.map(faq => ({ ...faq, isOpen: false }));
    }
}