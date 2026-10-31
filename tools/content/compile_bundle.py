#!/usr/bin/env python3
"""Compile only a validated release into deterministic, offline iOS resources."""
import argparse
import json
import shutil
import tempfile
from pathlib import Path
import release as r

COMPILER_VERSION=1

def catalog(manifest,docs,laws,articles):
    source_by_id=r.keyed(docs['sources'],'sources')
    def source(ids):return '\n'.join(source_by_id[i]['publisher']+' · '+source_by_id[i]['title']+'\n'+source_by_id[i]['url'] for i in ids)
    interpretations=r.keyed(docs['interpretations'],'interpretations')
    result=dict(schemaVersion=1,packageId=manifest['packageId'],kind='approved',laws=[],articles=[],cards=[],questions=[])
    symbols={'criminal':'leaf','civil':'house','public_security':'sun.max'}
    for law_id in ['criminal','civil','public_security']:
        edition,document=laws[law_id]
        result['laws'].append(dict(id=law_id,title=edition['name'],subtitle='复核至 '+edition['reviewedAt'][:7],symbol=symbols[law_id]))
        for article in document['articles']:
            reference=dict(lawId=law_id,lawVersionId=edition['lawVersionId'],editionId=edition['editionId'],articleKey=article['articleKey'])
            result['articles'].append(dict(reference=reference,number=article['displayNumber'],title=' / '.join(article['chapterPath']) or '法条原文',text=article['originalText'],source=source([article['sourceId']]),versionLabel=edition['effectiveAt']+' 施行版本 · 复核至 '+article['reviewedAt'][:7],reviewedAt=article['reviewedAt']))
    topics=r.keyed(docs['topics'],'topics')
    for card in docs['cards']:
        linked=[interpretations[i] for i in card['interpretationIds']]
        points=[p for item in linked for p in item['points']]
        result['cards'].append(dict(id=card['id'],revision=card['revision'],lawId=card['primaryLawId'],topic=' / '.join(topics[t]['title'] for t in card['topicIds']),title=card['title'],conclusion=card['conclusion']['text']+'\n'+card['conclusion']['qualifications'],story=card['story']['text']+'\n'+card['story']['adaptationNote'],points=[p['text'] for p in points],pointReferences=[p['articleRefs'] for p in points],misconception='\n'.join(p['text'] for item in linked for p in item['misconceptions']),consequences=[q for item in linked for q in item['consequences']],articleRefs=card['articleRefs'],questionId=card['quizIds'][0],questionIds=card['quizIds'],minutes=3,source=source(card['sourceIds']),reviewedAt=card['reviewedAt'],category=card['conclusion']['category'],scenarioLabel='官方案例改编' if card['story']['kind']=='official_case_adaptation' else '典型情境示例'))
    for question in docs['questions']:
        result['questions'].append(dict(id=question['id'],revision=question['revision'],prompt=question['prompt'],options=question['options'],correctOptionId=question['correctOptionIds'][0],explanation=question['explanation'],cardId=question['cardIds'][0],cardIds=question['cardIds'],articleRefs=question['articleRefs'],reviewedAt=question['reviewedAt']))
    result['coursePlan']=dict(id=manifest['packageId']+'.'+docs['courses']['rulesVersion'],levels=[dict(id=l['id'],title=l['title'],rank=l['rankId'],prerequisiteIDs=l['prerequisiteIds'],questionIDs=l['questionIds']) for l in docs['courses']['levels']])
    result['searchAliases']=[dict(term=a['term'],pinyin=a['pinyin'],initials=a['initials'],lawId=a['lawId'],isLaw=a.get('kind','law')=='law') for a in docs['aliases']]
    result['migrations']=docs['migrations']
    return result

def normalize(text):
    return ''.join(chr(ord(c)-65248) if 65281<=ord(c)<=65374 else ' ' if c=='\u3000' else c for c in text).lower().strip()

def search_index(value,data):
    titles={law['id']:law['title'] for law in value['laws']}
    fields=[];postings={}
    for position,article in enumerate(value['articles']):
        values=[normalize(article['title']),normalize(article['text']),normalize(titles[article['reference']['lawId']])]
        fields.append(values);tokens=set()
        for text in values:
            tokens.update(text);tokens.update(text[i:i+2] for i in range(len(text)-1))
        for token in sorted(tokens):postings.setdefault(token,[]).append(position)
    return dict(version=1,packageId=value['packageId'],sourceDigest=r.digest(data),fields=fields,postings=postings)

def compile_release(package,reviewers,sources,output,today=None):
    manifest,docs,laws,articles=r.validate(package,reviewers,sources,today)
    value=catalog(manifest,docs,laws,articles);data=r.canonical(value)
    index=r.canonical(search_index(value,data))
    require_size=len(data)+len(index)+sum(f['bytes'] for f in manifest['files'])
    r.require(require_size<=15*1024*1024,'compiled content plus review records exceeds 15 MB')
    r.require(output.resolve()!=package.resolve() and package.resolve() not in output.resolve().parents and output.resolve() not in package.resolve().parents,'output must be separate from the source release')
    if output.exists() and any(output.iterdir()):
        generated=(output/'.lawsense-generated').exists()
        placeholder={p.name for p in output.iterdir()}=={'README.txt'} and (output/'README.txt').read_text().startswith('No approved content configured.')
        r.require(generated or placeholder,'refusing to replace a directory not owned by this generator')
    output.parent.mkdir(parents=True,exist_ok=True)
    temporary=Path(tempfile.mkdtemp(prefix='lawsense-build-',dir=output.parent))
    try:
        for name in ['manifest.json']+[f['path'] for f in manifest['files']]:
            target=temporary/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(package/name,target)
        (temporary/'approved-catalog.json').write_bytes(data)
        (temporary/'search-index.json').write_bytes(index)
        (temporary/'.lawsense-generated').write_text('LawSense content compiler v1\n')
        receipt=dict(compilerVersion=COMPILER_VERSION,packageId=manifest['packageId'],manifestSHA256=r.digest((package/'manifest.json').read_bytes()),catalogSHA256=r.digest(data),indexSHA256=r.digest(index))
        (temporary/'receipt.json').write_bytes(r.canonical(receipt))
        r.require(sum(p.stat().st_size for p in temporary.rglob('*') if p.is_file())<=15*1024*1024,'final content bundle exceeds 15 MB')
        # Stage all bytes first; an interrupted replacement never mutates source releases.
        backup=None
        if output.exists():
            backup=Path(tempfile.mkdtemp(prefix='lawsense-previous-',dir=output.parent));backup.rmdir();output.rename(backup)
        try:temporary.rename(output)
        except BaseException:
            if backup:backup.rename(output)
            raise
        if backup:shutil.rmtree(backup)
    finally:shutil.rmtree(temporary,ignore_errors=True)
    return receipt

def verify_generated(output,reviewers,sources,today=None):
    manifest,docs,laws,articles=r.validate(output,reviewers,sources,today)
    value=catalog(manifest,docs,laws,articles);data=r.canonical(value)
    index=r.canonical(search_index(value,data))
    r.require((output/'approved-catalog.json').read_bytes()==data,'generated catalog differs from approved sources')
    expected=dict(compilerVersion=COMPILER_VERSION,packageId=manifest['packageId'],manifestSHA256=r.digest((output/'manifest.json').read_bytes()),catalogSHA256=r.digest(data),indexSHA256=r.digest(index))
    r.require((output/'search-index.json').read_bytes()==index,'generated search index differs from approved sources')
    r.require(sum(p.stat().st_size for p in output.rglob('*') if p.is_file())<=15*1024*1024,'final bundle content exceeds 15 MB')
    r.require(r.read(output/'receipt.json')==expected,'compiled receipt mismatch')
    return expected

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--output',type=Path,default=r.ROOT/'ios/ApprovedContent');parser.add_argument('--reviewers',type=Path,default=r.ROOT/'resource/content/reviewers.json');parser.add_argument('--sources',type=Path,default=r.ROOT/'resource/content/source')
    args=parser.parse_args()
    try:print(json.dumps(compile_release(args.package,r.read(args.reviewers),args.sources,args.output),ensure_ascii=False))
    except (r.Invalid,OSError,ValueError,KeyError) as error:parser.exit(1,'Content compilation rejected: '+str(error)+'\n')
