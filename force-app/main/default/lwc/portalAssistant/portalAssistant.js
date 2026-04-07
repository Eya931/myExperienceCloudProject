import { LightningElement, track } from 'lwc';
import getAssistantResponse from '@salesforce/apex/PortalController.getAssistantResponse';

const BOT_NAME = 'TalentBridge Assistant';
const VALIDATION_CHECKLIST = 'Validate in Experience Cloud with a real candidate user: profile edit, CV upload, applications stage flow, and interview reminders.';

export default class PortalAssistant extends LightningElement {
    @track inputMessage = '';
    @track isSending = false;
    @track lastErrorMessage = '';
    @track chatItems = [
        {
            id: 'w1',
            role: 'bot',
            author: BOT_NAME,
            text: `Hello. I can help you track your application stages, interview updates, and profile actions. ${VALIDATION_CHECKLIST}`,
            cssClass: 'msg bot'
        }
    ];

    quickPrompts = [
        'What is my next step?',
        'How to improve my profile completion?',
        'How interview reminders work?',
        'Validation checklist'
    ];

    get isSendDisabled() {
        return this.isSending;
    }

    handleInputChange(event) {
        this.inputMessage = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.sendMessage();
        }
    }

    handleQuickPrompt(event) {
        const prompt = event.currentTarget.dataset.prompt;
        if (!prompt) {
            return;
        }
        this.inputMessage = prompt;
        this.sendMessage();
    }

    async sendMessage() {
        const text = (this.inputMessage || '').trim();
        if (!text) {
            return;
        }

        this.isSending = true;

        const userMsg = {
            id: `u-${Date.now()}`,
            role: 'user',
            author: 'You',
            text,
            cssClass: 'msg user'
        };

        this.chatItems = [...this.chatItems, userMsg];
        this.inputMessage = '';

        try {
            const response = await getAssistantResponse({ message: text });
            this.lastErrorMessage = '';
            const botMsg = {
                id: `b-${Date.now()}`,
                role: 'bot',
                author: response?.source === 'salesforce-ai' ? `${BOT_NAME} (Salesforce AI)` : BOT_NAME,
                text: response?.text || 'No response available.',
                cssClass: 'msg bot'
            };
            this.chatItems = [...this.chatItems, botMsg];
        } catch (e) {
            this.lastErrorMessage = e?.body?.message || e?.message || 'Assistant request failed.';
            const botMsg = {
                id: `b-${Date.now()}`,
                role: 'bot',
                author: BOT_NAME,
                text: 'Assistant service is unavailable right now. Please try again in a moment.',
                cssClass: 'msg bot'
            };
            this.chatItems = [...this.chatItems, botMsg];
        } finally {
            this.isSending = false;
        }
    }
}
