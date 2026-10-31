#!/usr/bin/env python3
"""Offline release checks. Structural approval evidence is not a legal opinion."""
import argparse
import calendar
import hashlib
import json
from itertools import product
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlparse
from jsonschema import Draft202012Validator, FormatChecker
from generate_schema import schema

ROOT = Path(__file__).resolve().parents[2]
DOCUMENTS = ('sources','interpretations','cards','questions','topics','courses','aliases','migrations','approvals')
LAWS = {'criminal','civil','public_security'}

class Invalid(ValueError): pass

def require(condition, message):
    if not condition: raise Invalid(message)
def canonical(value): return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf-8')
def digest(value): return hashlib.sha256(value).hexdigest()
def object_digest(value): return digest(canonical(value))
def pairs(values):
    result={}
    for key,value in values:
        require(key not in result, 'duplicate JSON key: '+key)
        result[key]=value
    return result

def read(path):
    require(path.stat().st_size <= 15*1024*1024, str(path)+': file exceeds 15 MB')
    try: return json.loads(path.read_text(encoding='utf-8'),object_pairs_hook=pairs,parse_constant=lambda x: (_ for _ in ()).throw(Invalid('non-finite JSON number')))
    except (UnicodeError,json.JSONDecodeError) as error: raise Invalid(str(path)+': '+str(error)) from error

def confined(root, relative):
    require(isinstance(relative,str) and relative and not Path(relative).is_absolute() and '..' not in Path(relative).parts and '\\' not in relative, 'unsafe path: '+str(relative))
    path=root/relative
    require(root.resolve() in path.resolve().parents and not path.is_symlink(), 'path escapes package: '+relative)
    return path

def check_schema(value, name):
    definition=schema()
    definition['$ref']='#/$defs/'+name
    errors=sorted(Draft202012Validator(definition,format_checker=FormatChecker()).iter_errors(value),key=lambda e:str(list(e.path)))
    if errors: raise Invalid(name+'/'+ '/'.join(map(str,errors[0].path))+': '+errors[0].message)

def keyed(values, label):
    keys=[v['id'] for v in values]
    require(len(keys)==len(set(keys)),label+': duplicate ID')
    return dict(zip(keys,values))
def ref_key(value): return tuple(value[k] for k in ('lawId','lawVersionId','editionId','articleKey'))
def package_digest(manifest):
    value=dict(manifest,files=[f for f in manifest['files'] if f['path']!='approvals.json'])
    return object_digest(value)
def six_months_before(value):
    month=value.year*12+value.month-1-6
    year,month=divmod(month,12);month+=1
    return date(year,month,min(value.day,calendar.monthrange(year,month)[1]))
def reviewed(value, today, label):
    actual=date.fromisoformat(value)
    require(six_months_before(today)<=actual<=today,label+': future or older-than-six-calendar-month review')
def acyclic(entries, dependencies, label):
    ids=set(entries); done=set()
    for key,value in entries.items(): require(set(dependencies(value))<=ids,label+': missing dependency '+key)
    while len(done)<len(ids):
        ready={k for k,v in entries.items() if k not in done and set(dependencies(v))<=done}
        require(ready,label+': cyclic dependencies');done.update(ready)

def validate(package, reviewers, source_root, today=None):
    today=today or datetime.now(timezone(timedelta(hours=8))).date()
    manifest=read(package/'manifest.json');check_schema(manifest,'manifest')
    require(date.fromisoformat(manifest['createdAt'])<=today,'manifest: future creation date')
    require(not manifest['packageId'].startswith(('development','demo','test')), 'development package cannot be released')
    file_map={f['path']:f for f in manifest['files']}
    require(len(file_map)==len(manifest['files']),'manifest: duplicate file paths')
    expected={name+'.json' for name in DOCUMENTS}|{'laws/'+e['editionId']+'.json' for e in manifest['lawEditions']}
    require(set(file_map)==expected,'manifest: missing or unexpected payload files')
    require(sum(f['bytes'] for f in file_map.values())<=15*1024*1024,'content payload exceeds 15 MB')
    for relative,record in file_map.items():
        path=confined(package,relative)
        require(path.is_file() and path.stat().st_size==record['bytes'],relative+': byte count or SHA-256 mismatch')
        data=path.read_bytes()
        require(len(data)==record['bytes'] and digest(data)==record['sha256'],relative+': byte count or SHA-256 mismatch')
    docs={name:read(package/(name+'.json')) for name in DOCUMENTS}
    for name,value in docs.items(): check_schema(value,name)
    sources=keyed(docs['sources'],'sources');approvals=keyed(docs['approvals'],'approvals')
    registry=keyed(reviewers['reviewers'],'reviewers')
    for source in sources.values():
        parsed=urlparse(source['url']);host=(parsed.hostname or '').lower()
        roots=('npc.gov.cn','gov.cn','court.gov.cn','spp.gov.cn','mps.gov.cn','moj.gov.cn')
        require(parsed.scheme=='https' and not parsed.username and not parsed.password and any(host==r or host.endswith('.'+r) for r in roots),source['id']+': unapproved source domain')
        if 'publishedAt' in source: require(source['publishedAt']<=source['retrievedAt'],source['id']+': publication occurs after retrieval')
        if source['kind']=='law': require(host=='flk.npc.gov.cn',source['id']+': law text must originate from NPC database')
        require(date.fromisoformat(source['retrievedAt'])<=today,source['id']+': future retrieval')
        snapshot=confined(source_root,source['snapshotPath'])
        require(snapshot.is_file() and snapshot.stat().st_size<=100*1024*1024 and digest(snapshot.read_bytes())==source['snapshotHash'],source['id']+': missing or modified source snapshot')
    def approved(identifier,key,value,roles,minimum_people=1):
        require(identifier in approvals,key+': missing approval '+identifier)
        approval=approvals[identifier];expected_digest=value if isinstance(value,str) else object_digest(value)
        require(approval['objectKey']==key and approval['objectDigest']==expected_digest,key+': stale approval digest')
        people=set();covered=set();people_by_role={role:set() for role in roles}
        for review in approval['reviews']:
            person=registry.get(review['reviewerId'])
            require(person and person.get('active') is True and review['role'] in person.get('roles',[]),key+': unknown or unauthorized reviewer')
            require(review['objectDigest']==expected_digest,key+': stale reviewer attestation digest')
            reviewed(review['reviewedAt'],today,key)
            minimum_date=manifest['createdAt'] if isinstance(value,str) else value.get('reviewedAt', value.get('edition',{}).get('reviewedAt','0001-01-01'))
            require(review['reviewedAt']>=minimum_date,key+': review predates its subject')
            people.add(review['reviewerId']);covered.add(review['role'])
            if review['role'] in people_by_role: people_by_role[review['role']].add(review['reviewerId'])
        require(set(roles)<=covered and len(people)>=minimum_people,key+': missing independent review roles')
        if len(roles)==1:
            require(len(people_by_role[roles[0]])>=minimum_people,key+': missing independent reviewers for required role')
        else:
            require(any(len(set(assignment))==len(roles) for assignment in product(*(people_by_role[role] for role in roles))),key+': missing independent required review roles')
        return approval
    articles={};laws={}
    require({e['lawId'] for e in manifest['lawEditions']}==LAWS and len(manifest['lawEditions'])==3,'manifest: exactly three current law editions required')
    for edition in manifest['lawEditions']:
        key='law:'+edition['editionId'];document=read(package/'laws'/(edition['editionId']+'.json'));check_schema(document,'law')
        require(document['editionId']==edition['editionId'],key+': edition identity mismatch')
        reviewed(edition['reviewedAt'],today,key)
        require(edition['promulgatedAt']<=edition['effectiveAt']<=edition['reviewedAt'],key+': inconsistent dates')
        require(edition['sourceId'] in sources and sources[edition['sourceId']]['kind']=='law',key+': missing official source')
        entries=document['articles'];inventory=[a['articleKey'] for a in entries]
        require(len(inventory)==len(set(inventory))==edition['articleCount'],key+': article inventory count or duplicates')
        require(object_digest(inventory)==edition['articleInventoryHash'],key+': article inventory differs from reviewed list')
        require([a['order'] for a in entries]==sorted(set(a['order'] for a in entries)),key+': article order must be unique and ascending')
        for article in entries:
            reviewed(article['reviewedAt'],today,key+'/'+article['articleKey'])
            require(article['sourceId']==edition['sourceId'],key+': article source mismatch')
            require(digest(article['originalText'].encode())==article['textHash'],key+': original text hash mismatch')
            require(article['originalText'].startswith(article['displayNumber']),key+': original must retain its article number')
            articles[(edition['lawId'],edition['lawVersionId'],edition['editionId'],article['articleKey'])]=article
        matches=[a['id'] for a in approvals.values() if a['objectKey']==key]
        require(len(matches)==1,key+': one law approval required')
        approved(matches[0],key,dict(edition=edition,document=document,source=sources[edition['sourceId']]),['proofreader'],2)
        laws[edition['lawId']]=(edition,document)
    def references(values,label):
        require(values and all(ref_key(r) in articles for r in values),label+': unresolved exact article reference')
    interpretations=keyed(docs['interpretations'],'interpretations');cards=keyed(docs['cards'],'cards');questions=keyed(docs['questions'],'questions');topics=keyed(docs['topics'],'topics')
    for kind,items in [('interpretation',interpretations),('card',cards),('question',questions)]:
        for item in items.values():
            key=kind+':'+item['id'];reviewed(item['reviewedAt'],today,key);references(item['articleRefs'],key)
            approved(item['approvalId'],key,item,['legal_reviewer'])
    for item in interpretations.values():
        for point in item['points']+item['misconceptions']:
            references(point['articleRefs'],item['id'])
            require(set(map(ref_key,point['articleRefs']))<=set(map(ref_key,item['articleRefs'])),item['id']+': point citation missing from interpretation references')
        for quote in item['consequences']:
            references([quote['articleRef']],item['id'])
            require(ref_key(quote['articleRef']) in set(map(ref_key,item['articleRefs'])),item['id']+': quote citation missing from interpretation references')
            require(quote['quote'] in articles[ref_key(quote['articleRef'])]['originalText'],item['id']+': altered consequence quotation')
    require(len(cards)>=100 and len(questions)>=300,'release requires >=100 cards and >=300 questions')
    for law,count in [('criminal',40),('civil',45),('public_security',15)]:
        require(sum(c['primaryLawId']==law for c in cards.values())>=count,law+': insufficient knowledge cards')
    required_topics=read(ROOT/'resource/content/v1-requirements.json')['requiredTopicIds']
    for law,required_ids in required_topics.items():
        require(all(t in topics and topics[t]['lawId']==law and topics[t]['requiredForV1'] for t in required_ids),law+': mandatory V1 topic missing or disabled')
    acyclic(topics,lambda t:[t['parentId']] if 'parentId' in t else [],'topics')
    for topic in topics.values():
        require(topic['lawId'] in LAWS,topic['id']+': unknown law')
        if 'parentId' in topic: require(topics[topic['parentId']]['lawId']==topic['lawId'],topic['id']+': parent belongs to another law')
        if topic['requiredForV1']: require(any(topic['id'] in c['topicIds'] for c in cards.values()),topic['id']+': required topic is uncovered')
    for card in cards.values():
        require(card['primaryLawId'] in LAWS and set(card['topicIds'])<=set(topics) and set(card['interpretationIds'])<=set(interpretations) and set(card['sourceIds'])<=set(sources),card['id']+': missing topic, interpretation or source')
        require(all(topics[t]['lawId']==card['primaryLawId'] for t in card['topicIds']),card['id']+': topic belongs to another law')
        for interpretation_id in card['interpretationIds']:
            require(set(map(ref_key,interpretations[interpretation_id]['articleRefs']))<=set(map(ref_key,card['articleRefs'])),card['id']+': interpretation citation missing from card')
        if card['story']['kind']=='official_case_adaptation': require(any(sources[s]['kind']=='case' for s in card['sourceIds']),card['id']+': case adaptation lacks case source')
        require(all(q in questions and card['id'] in questions[q]['cardIds'] for q in card['quizIds']),card['id']+': quiz reverse link missing')
    for question in questions.values():
        options=keyed(question['options'],question['id'])
        require(question['correctOptionIds'][0] in options,question['id']+': correct option missing')
        require(all(c in cards and question['id'] in cards[c]['quizIds'] for c in question['cardIds']),question['id']+': card reverse link missing')
    levels=keyed(docs['courses']['levels'],'levels');acyclic(levels,lambda l:l['prerequisiteIds'],'courses')
    require({l['rankId'] for l in levels.values()}==set(docs['courses']['ranks']),'courses: missing rank')
    for level in levels.values():
        require(len(level['questionIds'])==len(set(level['questionIds'])) and set(level['questionIds'])<=set(questions) and set(level['cardIds'])<=set(cards),level['id']+': missing or duplicated course content')
    require(LAWS<={a['lawId'] for a in docs['aliases'] if a['kind']=='law'},'aliases: each law requires reviewed search terms')
    require(len({(a['term'],a['lawId']) for a in docs['aliases']})==len(docs['aliases']),'aliases: duplicate terms')
    law_names={}
    for alias in docs['aliases']:
        require(alias['lawId'] in LAWS,'alias: invalid law')
        if alias['kind']=='law':
            for term in [alias['term'].lower(),alias['pinyin'],alias['initials']]:
                require(term not in law_names or law_names[term]==alias['lawId'],'aliases: ambiguous law identity')
                law_names[term]=alias['lawId']
    for migration in docs['migrations']:
        require((migration['change']=='removed')==(not migration['newIds']),'migration: removed targets must be empty')
        if migration['kind']=='article':
            current_ids={''.join(str(len(part.encode()))+':'+part for part in key) for key in articles}
            require(set(migration['newIds'])<=current_ids,'migration: exact article target missing')
        if migration['kind']!='article': require(set(migration['newIds'])<=set(cards if migration['kind']=='card' else questions),'migration: missing target')
    approval=approved(manifest['releaseApprovalId'],'package:'+manifest['packageId'],package_digest(manifest),['content_owner','lawyer'],2)
    object_keys={'card:'+k for k in cards}|{'question:'+k for k in questions}|{'interpretation:'+k for k in interpretations}
    require(approval['sampledObjectKeys'] and set(approval['sampledObjectKeys'])<=object_keys,'package: lawyer sampling scope missing or invalid')
    return manifest,docs,laws,articles

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--reviewers',type=Path,default=ROOT/'resource/content/reviewers.json');parser.add_argument('--sources',type=Path,default=ROOT/'resource/content/source')
    args=parser.parse_args()
    try:
        manifest,*_=validate(args.package,read(args.reviewers),args.sources)
        print('Validated structural release evidence:',manifest['packageId'])
    except (Invalid,OSError,ValueError,KeyError) as error:
        parser.exit(1,'Content release rejected: '+str(error)+'\n')
