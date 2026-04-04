import { LightningElement } from 'lwc';
export default class PortalStatistics extends LightningElement {
    get statCards() {
        return [
            { id:'1', label:'Total Applications', value:'2',  sub:'this month' },
            { id:'2', label:'Interviews Secured', value:'1',  sub:'50% conversion' },
            { id:'3', label:'Profile Views',       value:'14', sub:'this week' },
            { id:'4', label:'CV Downloads',        value:'3',  sub:'by recruiters' },
        ];
    }
    get skills() {
        return [
            { name:'React',      pct:90, fillClass:'bar-fill bar-fill-n', widthStyle:'width:90%' },
            { name:'TypeScript', pct:80, fillClass:'bar-fill bar-fill-o', widthStyle:'width:80%' },
            { name:'Node.js',    pct:70, fillClass:'bar-fill bar-fill-n', widthStyle:'width:70%' },
            { name:'Figma',      pct:65, fillClass:'bar-fill bar-fill-n', widthStyle:'width:65%' },
            { name:'GraphQL',    pct:55, fillClass:'bar-fill bar-fill-o', widthStyle:'width:55%' },
        ];
    }
    get activities() {
        return [
            { id:'1', dotClass:'act-dot dot-o', text:'CV passed screening for Senior Frontend Engineer — coding test assigned', time:'2h ago' },
            { id:'2', dotClass:'act-dot dot-n', text:'Applied to Product Designer at Pulse · Hybrid Tunis',                  time:'Jan 8'  },
            { id:'3', dotClass:'act-dot dot-n', text:'Applied to Senior Frontend Engineer at Pulse · Remote',                time:'Jan 15' },
            { id:'4', dotClass:'act-dot dot-g', text:'Profile created and CV uploaded — Amira_CV_2025.pdf',                  time:'Jan 6'  },
        ];
    }
}