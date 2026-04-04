import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import heroImage from '@salesforce/resourceUrl/heroImage';
import header2 from '@salesforce/resourceUrl/header2';
import header3 from '@salesforce/resourceUrl/header3';
import getJobs from '@salesforce/apex/JobController.getJobs';
import isGuestUser from '@salesforce/user/isGuest';

export default class TalentBridgeHero extends NavigationMixin(LightningElement) {

    // --- Carousel ---
    @track _currentIndex  = 0;
    _totalSlides          = 3;
    _timer                = null;
    _slidesInitialized    = false;

    // --- Auth ---
    isGuest = isGuestUser;

    // --- Jobs ---
    @track allJobs;

    // --- Search state ---
    @track searchTerm     = '';
    @track locationTerm   = '';
    @track selectedType   = '';
    @track showSuggestions = false;

    // ─────────────────────────────────────────────
    // Apex wire
    // ─────────────────────────────────────────────
    @wire(getJobs)
    wiredJobs({ data }) {
        if (data) this.allJobs = data;
    }

    // ─────────────────────────────────────────────
    // Stats
    // ─────────────────────────────────────────────
    get totalJobs() {
        return this.allJobs ? this.allJobs.length : 0;
    }

    get totalDepartments() {
        if (!this.allJobs) return 0;
        return new Set(this.allJobs.map(j => j.Department__c).filter(Boolean)).size;
    }

    get totalLocations() {
        if (!this.allJobs) return 0;
        return new Set(this.allJobs.map(j => j.Location__c).filter(Boolean)).size;
    }

    get typeOptions() {
        if (!this.allJobs) return [];
        return [...new Set(this.allJobs.map(j => j.Employment_Type__c).filter(Boolean))];
    }

    // ─────────────────────────────────────────────
    // Location suggestions
    // ─────────────────────────────────────────────
    get filteredLocations() {
        if (!this.allJobs) return [];
        const term = (this.locationTerm || '').toLowerCase().trim();
        const all  = [...new Set(this.allJobs.map(j => j.Location__c).filter(Boolean))];
        return term === ''
            ? all.slice(0, 6)
            : all.filter(l => l.toLowerCase().includes(term)).slice(0, 6);
    }

    // ─────────────────────────────────────────────
    // FIND NOW — write to localStorage, jobCards
    // listens via window 'storage' event on same page
    // ─────────────────────────────────────────────
    // Write filters to localStorage on every change
    // jobCards polls every 100ms and picks up the new timestamp
    _writeFilters() {
        try {
            localStorage.setItem('tbFilters', JSON.stringify({
                search:   this.searchTerm   || '',
                location: this.locationTerm || '',
                type:     this.selectedType || '',
                ts:       Date.now(),
            }));
        } catch(e) { /* storage unavailable */ }
    }

    handleSearch() {
        this._writeFilters();
    }

    // ─────────────────────────────────────────────
    // Search handlers — write on every keystroke
    // ─────────────────────────────────────────────
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this._writeFilters(); // instant filter as user types
    }

    handleLocationChange(event) {
        this.locationTerm = event.target.value;
        this.showSuggestions = true;
        this._writeFilters(); // instant filter as user types
    }

    handleLocationFocus() {
        this.showSuggestions = true;
    }

    handleLocationBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showSuggestions = false; }, 150);
    }

    handleSuggestionPick(event) {
        this.locationTerm    = event.currentTarget.dataset.value;
        this.showSuggestions = false;
        this._writeFilters();
    }

    handleJobTypeChange(event) {
        this.selectedType = event.target.value;
        this._writeFilters(); // instant filter on dropdown change
    }

    // ─────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────
    renderedCallback() {
        if (this._slidesInitialized) return;
        this._slidesInitialized = true;
        this.template.querySelector('.slide-0').style.backgroundImage = 'url(' + header2 + ')';
        this.template.querySelector('.slide-1').style.backgroundImage = 'url(' + heroImage + ')';
        this.template.querySelector('.slide-2').style.backgroundImage = 'url(' + header3 + ')';
    }

    connectedCallback()    { this._startAutoPlay(); }
    disconnectedCallback() { this._stopAutoPlay();  }

    // ─────────────────────────────────────────────
    // Carousel
    // ─────────────────────────────────────────────
    get slide0Class() { return this._slideClass(0); }
    get slide1Class() { return this._slideClass(1); }
    get slide2Class() { return this._slideClass(2); }

    _slideClass(index) {
        return index === this._currentIndex
            ? 'slide slide-' + index + ' active'
            : 'slide slide-' + index;
    }

    get dot0Class() { return this._dotClass(0); }
    get dot1Class() { return this._dotClass(1); }
    get dot2Class() { return this._dotClass(2); }

    _dotClass(index) {
        return index === this._currentIndex ? 'dot active' : 'dot';
    }

    get slideLabel() {
        const pad = (n) => String(n).padStart(2, '0');
        return pad(this._currentIndex + 1) + ' / ' + pad(this._totalSlides);
    }

    _startAutoPlay() {
        this._timer = setInterval(() => { this._goTo(this._currentIndex + 1); }, 5500);
    }

    _stopAutoPlay() {
        if (this._timer) { clearInterval(this._timer); this._timer = null; }
    }

    _resetAutoPlay() { this._stopAutoPlay(); this._startAutoPlay(); }

    _goTo(index) {
        this._currentIndex = (index + this._totalSlides) % this._totalSlides;
    }

    handleNext()  { this._goTo(this._currentIndex + 1); this._resetAutoPlay(); }
    handlePrev()  { this._goTo(this._currentIndex - 1); this._resetAutoPlay(); }

    handleDotClick(event) {
        this._goTo(parseInt(event.currentTarget.dataset.index, 10));
        this._resetAutoPlay();
    }

    // ─────────────────────────────────────────────
    // Nav + Auth
    // ─────────────────────────────────────────────
    handleNavClick(event) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: event.currentTarget.dataset.page }
        });
    }

    handlePostJob() {
        this.dispatchEvent(new CustomEvent('postjob', { bubbles: true, composed: true }));
    }
}