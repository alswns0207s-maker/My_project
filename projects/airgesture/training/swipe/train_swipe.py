"""Train a temporal MLP with session/person-disjoint validation and test."""
import argparse,json
from pathlib import Path
import numpy as np
from swipe_features import features,softmax,LABELS,STEPS,DURATION

def load_data(root,group_by='session'):
    rows=[];labels=[];groups=[];paths=[];rejected=[]
    for p in sorted(Path(root).rglob('*.npz')):
        try:
            with np.load(p,allow_pickle=False) as d:
                meta=json.loads(str(d['metadata']))
                if meta.get('mirrored') is not True:raise ValueError('Unspecified mirrored direction')
                x=features(d['points'],d['timestamps'],meta['height']/meta['width'])
            y=LABELS.index(meta['label'])
            group=meta['person'] if group_by=='person' else meta['person']+'/'+meta['session']
            rows.append(x);labels.append(y);groups.append(group);paths.append(str(p))
        except (ValueError,KeyError,OSError) as e:rejected.append({'path':str(p),'reason':str(e)})
    if not rows:raise ValueError('No valid recordings. Use record_swipe.py first.')
    return np.stack(rows),np.array(labels),np.array(groups),paths,rejected

def split_groups(y,groups,seed):
    unique=np.unique(groups)
    if len(unique)<6:raise ValueError('Need at least 6 sessions (or 6 people for --group person); do not split adjacent frames.')
    rng=np.random.default_rng(seed)
    nval=max(1,round(len(unique)*.2));ntest=nval
    for _ in range(2000):
        order=rng.permutation(unique)
        gsets=(order[nval+ntest:],order[:nval],order[nval:nval+ntest])
        splits=[np.flatnonzero(np.isin(groups,g)) for g in gsets]
        if all(np.all(np.bincount(y[i],minlength=3)>=minimum) for i,minimum in zip(splits,(10,5,5))):
            return splits
    raise ValueError('Each split needs all 3 labels: train >=10/class, val/test >=5/class. Record all labels in every session.')

def metrics(y,p):
    cm=np.zeros((3,3),dtype=int)
    np.add.at(cm,(y,np.argmax(p,axis=1)),1)
    precision=np.diag(cm)/np.maximum(cm.sum(axis=0),1)
    recall=np.diag(cm)/np.maximum(cm.sum(axis=1),1)
    f1=2*precision*recall/np.maximum(precision+recall,1e-9)
    return {'accuracy':float(np.trace(cm)/len(y)),'macro_f1':float(f1.mean()),'recall':dict(zip(LABELS,recall.tolist())),'confusion_matrix':cm.tolist()}

def forward(x,w):
    h=np.maximum(0,x@w['w1']+w['b1'])
    return h,softmax(h@w['w2']+w['b2'])

def train(x,y,train_idx,val_idx,seed=42,epochs=160):
    rng=np.random.default_rng(seed)
    mean=x[train_idx].mean(axis=0);scale=np.maximum(x[train_idx].std(axis=0),.05)
    x=((x-mean)/scale).astype('float32')
    w={'w1':(rng.standard_normal((x.shape[1],64))*np.sqrt(2/x.shape[1])).astype('float32'),
       'b1':np.zeros(64,dtype='float32'),'w2':(rng.standard_normal((64,3))*np.sqrt(2/64)).astype('float32'),'b2':np.zeros(3,dtype='float32')}
    m={k:np.zeros_like(v) for k,v in w.items()};v={k:np.zeros_like(z) for k,z in w.items()}
    counts=np.bincount(y[train_idx],minlength=3);weights=len(train_idx)/(3*counts)
    best=None;best_loss=float('inf');stale=0;step=0;history=[]
    for epoch in range(epochs):
        order=rng.permutation(train_idx)
        for pos in range(0,len(order),32):
            ids=order[pos:pos+32];xb=x[ids];yb=y[ids];h,p=forward(xb,w)
            dz=p.copy();dz[np.arange(len(ids)),yb]-=1
            dz*=weights[yb,None]/len(ids)
            dh=(dz@w['w2'].T)*(h>0)
            grads={'w2':h.T@dz+1e-4*w['w2'],'b2':dz.sum(0),'w1':xb.T@dh+1e-4*w['w1'],'b1':dh.sum(0)}
            step+=1
            for k,g in grads.items():
                m[k]=.9*m[k]+.1*g;v[k]=.999*v[k]+.001*g*g
                w[k]-=.001*(m[k]/(1-.9**step))/(np.sqrt(v[k]/(1-.999**step))+1e-8)
        _,p=forward(x[val_idx],w)
        loss=float(-np.log(np.maximum(p[np.arange(len(val_idx)),y[val_idx]],1e-8)).mean())
        history.append({'epoch':epoch+1,'val_loss':loss})
        if loss<best_loss-1e-4:
            best_loss=loss;best={k:z.copy() for k,z in w.items()};stale=0
        else:stale+=1
        if (epoch+1)%10==0:print(f'epoch {epoch+1}: val_loss={loss:.4f}',flush=True)
        if stale>=20:break
    return {**best,'mean':mean,'scale':scale,'labels':np.array(LABELS),'steps':np.array(STEPS),'duration':np.array(DURATION)},history

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--data',default='swipe_data');ap.add_argument('--output',default='models/swipe_mlp.npz')
    ap.add_argument('--group',choices=['session','person'],default='session');ap.add_argument('--seed',type=int,default=42);ap.add_argument('--epochs',type=int,default=160)
    a=ap.parse_args()
    try:
        x,y,g,paths,rejected=load_data(a.data,a.group);splits=split_groups(y,g,a.seed)
        print('Clips by label:',dict(zip(LABELS,np.bincount(y,minlength=3).tolist())))
        model,history=train(x,y,splits[0],splits[1],a.seed,a.epochs)
    except ValueError as e:ap.error(str(e))
    output=Path(a.output);output.parent.mkdir(parents=True,exist_ok=True)
    np.savez_compressed(output,**model)
    normalized=(x-model['mean'])/model['scale']
    report={'labels':LABELS,'group_by':a.group,'seed':a.seed,'architecture':'24x66 -> 64 ReLU -> 3 softmax','history':history,'rejected':rejected}
    for name,ids in zip(('train','validation','test'),splits):
        report[name]={'count':len(ids),'groups':np.unique(g[ids]).tolist(),'files':[paths[i] for i in ids],**metrics(y[ids],forward(normalized[ids],model)[1])}
    report['note']='Session split does not prove generalization to unseen people. Continuous live false triggers need separate testing.'
    output.with_suffix('.report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Test:',json.dumps(report['test'],ensure_ascii=False)[:400]);print('Saved',output)

if __name__=='__main__':main()
