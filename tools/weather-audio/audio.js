'use strict';
const $ = id => document.getElementById(id);
let source = null, audioContext = null, playbackURL = null, busy = false;
const status = message => { $('status').textContent = message; };
const number = (id, lo, hi) => {
  const n = Number($(id).value);
  if (!Number.isFinite(n) || n < lo || n > hi) throw new Error(`${id} 超出允许范围 ${lo}–${hi}`);
  return n;
};
function randomGenerator(seed) {
  let x = seed >>> 0;
  return () => { x += 0x6D2B79F5; let a = x; a = Math.imul(a ^ a >>> 15, a | 1); a ^= a + Math.imul(a ^ a >>> 7, a | 61); return ((a ^ a >>> 14) >>> 0) / 4294967296; };
}
function synthesize(settings) {
  const sr = 44100, length = Math.round(settings.seconds * sr);
  const random = randomGenerator(settings.seed);
  const channels = [new Float32Array(length), new Float32Array(length)];
  const states = [{rain:0, wind:0, bass:0}, {rain:0, wind:0, bass:0}];
  for (let i = 0; i < length; i++) {
    const t = i / sr;
    for (let c = 0; c < 2; c++) {
      const s = states[c], noise = random()*2-1;
      s.rain += .27*(noise-s.rain);
      s.wind += .008*(noise-s.wind);
      s.bass += .0015*(noise-s.bass);
      const windSwell = .65+.2*Math.sin(t*.43+c*.15)+.12*Math.sin(t*.17);
      channels[c][i] = s.rain*.20*settings.rain + (s.wind-s.bass)*1.3*settings.wind*windSwell;
    }
  }
  for (let k = 0; k < settings.seconds*65; k++) {
    const offset = Math.floor(random()*length), count = Math.floor(sr*(.012+random()*.026));
    const pan = random(), amp = (.015+random()*.025)*settings.drops;
    let smooth = 0;
    for (let j = 0; j < count && offset+j < length; j++) {
      smooth += .5*(random()*2-1-smooth);
      const value = smooth * Math.min(1,j/70)*Math.exp(-j/(sr*.005))*amp;
      channels[0][offset+j] += value*Math.sqrt(1-pan);
      channels[1][offset+j] += value*Math.sqrt(pan);
    }
  }
  if (settings.thunder > 0) {
    for (let t0 = 1.5+random()*2; t0 < settings.seconds; t0 += 9+random()*9) {
      const offset = Math.floor(t0*sr), duration = 4+random()*3;
      let low = 0;
      for (let j = 0; j < sr*duration && offset+j < length; j++) {
        const t = j/sr;
        low += .018*(random()*2-1-low);
        const env = (1-Math.exp(-t/0.8))*Math.exp(-t/1.8)*Math.min(1,(duration-t)/.7);
        const value = low*1.6*settings.thunder*env;
        channels[0][offset+j] += value;
        channels[1][offset+j] += value*.92;
      }
    }
  }
  // Leave headroom; only reduce peaks, never amplify quiet presets.
  let peak = 0;
  for (const channel of channels) for (const value of channel) peak = Math.max(peak,Math.abs(value));
  const gain = peak > .75 ? .75/peak : 1;
  if (gain < 1) for (const channel of channels) for(let i=0;i<length;i++) channel[i] *= gain;
  return {channels, sampleRate:sr, duration:length/sr};
}
function wav(channels, sr) {
  const frames = channels[0].length, bytes = new ArrayBuffer(44+frames*4), view = new DataView(bytes);
  const text = (offset,value) => { for(let i=0;i<value.length;i++) view.setUint8(offset+i,value.charCodeAt(i)); };
  text(0,'RIFF'); view.setUint32(4,36+frames*4,true); text(8,'WAVE'); text(12,'fmt ');
  view.setUint32(16,16,true); view.setUint16(20,1,true); view.setUint16(22,2,true);
  view.setUint32(24,sr,true); view.setUint32(28,sr*4,true); view.setUint16(32,4,true); view.setUint16(34,16,true);
  text(36,'data'); view.setUint32(40,frames*4,true);
  for(let i=0;i<frames;i++) for(let c=0;c<2;c++) {
    const value = Math.max(-1,Math.min(1,channels[c][i]));
    view.setInt16(44+(i*2+c)*2,Math.round(value*(value<0?32768:32767)),true);
  }
  return new Blob([bytes],{type:'audio/wav'});
}
function setSource(value, label) {
  stop(); source = value;
  $('start').value = 0; $('end').value = (Math.floor(value.duration*1000)/1000).toFixed(3);
  $('start').max = $('end').max = value.duration;
  $('preview').disabled = $('export').disabled = false;
  const canvas = $('wave'), ctx = canvas.getContext('2d'), data = value.channels[0];
  ctx.clearRect(0,0,canvas.width,canvas.height);ctx.strokeStyle='#a7e4df';ctx.beginPath();
  for(let x=0;x<canvas.width;x++) {
    const a=Math.floor(x*data.length/canvas.width), b=Math.floor((x+1)*data.length/canvas.width);
    let min=0,max=0; for(let i=a;i<b;i++){min=Math.min(min,data[i]);max=Math.max(max,data[i]);}
    ctx.moveTo(x,80+min*140);ctx.lineTo(x,80+max*140);
  }
  ctx.stroke();status(`${label} · ${value.duration.toFixed(2)} 秒 · ${value.sampleRate} Hz`);
}
function edited() {
  if(!source) throw new Error('请先生成或导入音频');
  const start=number('start',0,source.duration), end=number('end',0,source.duration);
  if(end<=start) throw new Error('终点必须大于起点');
  const sr=source.sampleRate, a=Math.round(start*sr), b=Math.min(source.channels[0].length,Math.round(end*sr)), n=b-a;
  if(n<1) throw new Error('片段太短');
  const fade=Math.min(number('fade',0,10)*sr,n/2), gain=number('volume',0,100)/100;
  return wav(source.channels.map(ch=>{
    const out=ch.slice(a,b);
    for(let i=0;i<n;i++) out[i] *= gain*(fade>0?Math.min(1,i/fade,(n-1-i)/fade):1);
    return out;
  }),sr);
}
function stop(){ $('player').pause();$('player').removeAttribute('src');$('player').load(); if(playbackURL){URL.revokeObjectURL(playbackURL);playbackURL=null;} }
async function action(fn){if(busy)return;busy=true;try{await fn();}catch(error){status(error.message);}finally{busy=false;}}
for(const input of document.querySelectorAll('input[type=range]')) input.oninput=()=>input.nextElementSibling.value=input.value;
$('preset').onchange=()=>{
  const p={rain:[65,12,0,30],forest:[55,35,0,50],storm:[65,20,35,25],wind:[0,70,0,0]}[$('preset').value];
  ['rain','wind','thunder','drops'].forEach((id,i)=>{$(id).value=p[i];$(id).oninput();});
};
$('generate').onclick=()=>action(async()=>{
  const settings={seconds:number('seconds',5,120),seed:number('seed',1,4294967295)};
  for(const id of ['rain','wind','thunder','drops']) settings[id]=number(id,0,100)/100;
  status('正在生成…'); await new Promise(resolve=>setTimeout(resolve,30));
  setSource(synthesize(settings),'已生成天气音效');
});
$('file').onchange=()=>action(async()=>{
  const file=$('file').files[0];if(!file)return;
  if(file.size>100*1024*1024)throw new Error('请导入小于 100 MB 的音频');
  status('正在读取音频…');audioContext ||= new AudioContext();
  const buffer=await audioContext.decodeAudioData(await file.arrayBuffer());
  const channels=[buffer.getChannelData(0).slice(),buffer.getChannelData(Math.min(1,buffer.numberOfChannels-1)).slice()];
  setSource({channels,sampleRate:buffer.sampleRate,duration:buffer.duration},'已导入 '+file.name);
});
$('preview').onclick=()=>action(async()=>{const blob=edited();stop();playbackURL=URL.createObjectURL(blob);$('player').src=playbackURL;await $('player').play();status('正在试听编辑结果');});
$('export').onclick=()=>action(async()=>{const blob=edited(),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='raining-weather.wav';a.click();setTimeout(()=>URL.revokeObjectURL(url),10000);status('已导出 WAV');});
$('stop').onclick=stop;
