import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import login from '@salesforce/apex/LoginController.login';
import HERO_IMAGE from '@salesforce/resourceUrl/heroImage';

export default class LoginPage extends NavigationMixin(LightningElement) {
    username = '';
    password = '';
    errorMessage = '';
    isLoading = false;
    showPassword = false;

    @api forgotPasswordUrl = '/ForgotPassword';
    @api selfRegisterUrl = '/SelfRegister';
    @api startUrl = '/';
    _brandRendered = false;

    renderedCallback() {
        if (!this._brandRendered) {
            const panel = this.template.querySelector('[data-id="brandPanel"]');
            if (panel) {
                panel.style.backgroundImage = `url(${HERO_IMAGE})`;
                panel.style.backgroundSize = 'cover';
                panel.style.backgroundPosition = 'center';
                this._brandRendered = true;
            }
        }
    }

    get passwordFieldType() {
        return this.showPassword ? 'text' : 'password';
    }

    get loginBtnClass() {
        return this.isLoading ? 'login-btn loading' : 'login-btn';
    }

    handleUsernameChange(event) {
        this.username = event.target.value;
        this.errorMessage = '';
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
        this.errorMessage = '';
    }

    togglePassword() {
        this.showPassword = !this.showPassword;
    }

    handleKeyUp(event) {
        if (event.key === 'Enter') this.handleLogin();
    }

    handleLogin() {
        if (!this.username || !this.password) {
            this.errorMessage = 'Please enter both email and password.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        login({ username: this.username, password: this.password, startUrl: this.startUrl })
            .then((result) => {
                if (result) globalThis.location.href = result;
            })
            .catch((error) => {
                this.errorMessage =
                    error?.body?.message || 'Invalid credentials. Please try again.';
            })
            .finally(() => (this.isLoading = false));
    }
}