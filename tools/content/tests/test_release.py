"""Synthetic structural fixtures only; no real law text or review attestation."""
import copy
import json
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import release as r

class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.package=self.root/'package';self.package.mkdir();self.sources=self.root/'sources';self.sources.mkdir()
        self.today=date(2026,10,31);self.when='2026-10-20';self.docs={};self.approvals=[]
        self.registry={'reviewers':[{'id':key,'active':True,'roles':[role]} for key,role in [('p1','proofreader'),('p2','proofreader'),('legal','legal_reviewer'),('owner','content_owner'),('lawyer','lawyer')]]}
        sources=[];editions=[];refs={}
        for law in sorted(r.LAWS):
            snapshot=(law+' SYNTHETIC TEST ONLY').encode();(self.sources/(law+'.txt')).write_bytes(snapshot)
            sources.append(dict(id=law,kind='law',publisher='Synthetic test authority',title='Synthetic test source',url='https://flk.npc.gov.cn/fixture-not-real',retrievedAt=self.when,snapshotPath=law+'.txt',snapshotHash=r.digest(snapshot)))
            text='第一条 合成结构测试，不是法律原文。'
            article=dict(articleKey='1',displayNumber='第一条',chapterPath=[],order=1,originalText=text,textHash=r.digest(text.encode()),reviewedAt=self.when,sourceId=law)
            doc=dict(editionId=law+'-e1',articles=[article]);self.docs['laws/'+law+'-e1.json']=doc
            self.approve('law-'+law,'law:'+law+'-e1',doc,['p1','p2'])
            editions.append(dict(lawId=law,lawVersionId='v1',editionId=law+'-e1',name='Synthetic '+law,promulgatedAt='2026-01-01',effectiveAt='2026-01-02',statusAtReview='effective',reviewedAt=self.when,sourceId=law,articleCount=1,articleInventoryHash=r.object_digest(['1'])))
            refs[law]=dict(lawId=law,lawVersionId='v1',editionId=law+'-e1',articleKey='1')
        for edition in editions:
            approval=next(a for a in self.approvals if a['objectKey']=='law:'+edition['editionId'])
            source=next(s for s in sources if s['id']==edition['sourceId'])
            approval['objectDigest']=r.object_digest(dict(edition=edition,document=self.docs['laws/'+edition['editionId']+'.json'],source=source))
            for review in approval['reviews']:review['objectDigest']=approval['objectDigest']
        cards=[];questions=[];interpretations=[]
        required_topics=r.read(r.ROOT/'resource/content/v1-requirements.json')['requiredTopicIds']
        for law,count in [('criminal',40),('civil',45),('public_security',15)]:
            for index in range(count):
                cid=law+'-'+str(index);qid=[cid+'-q'+str(i) for i in range(3)];iid=cid+'-interpretation'
                interpretation=dict(id=iid,revision=1,points=[dict(text='Synthetic explanation',articleRefs=[refs[law]])],misconceptions=[dict(text='Synthetic misconception',articleRefs=[refs[law]])],consequences=[],articleRefs=[refs[law]],reviewedAt=self.when,approvalId='approval-'+iid,state='approved')
                interpretations.append(interpretation);self.approve(interpretation['approvalId'],'interpretation:'+iid,interpretation,['legal'])
                card=dict(id=cid,revision=1,primaryLawId=law,topicIds=[required_topics[law][index%len(required_topics[law])]],title='Synthetic test card',conclusion=dict(category='attention',text='Synthetic conclusion',qualifications='Only a fixture'),story=dict(kind='illustrative_scenario',text='Synthetic story',adaptationNote='Not a real event'),interpretationIds=[iid],articleRefs=[refs[law]],sourceIds=[law],quizIds=qid,reviewedAt=self.when,approvalId='approval-'+cid,state='approved')
                cards.append(card);self.approve(card['approvalId'],'card:'+cid,card,['legal'])
                for key in qid:
                    question=dict(id=key,revision=1,kind='single_choice',prompt='Synthetic question',options=[dict(id='a',text='A'),dict(id='b',text='B')],correctOptionIds=['a'],explanation='Synthetic explanation',cardIds=[cid],articleRefs=[refs[law]],reviewedAt=self.when,approvalId='approval-'+key,state='approved')
                    questions.append(question);self.approve(question['approvalId'],'question:'+key,question,['legal'])
        ranks=['bronze','silver','gold','master']
        self.docs.update({'sources.json':sources,'interpretations.json':interpretations,'cards.json':cards,'questions.json':questions,'topics.json':[dict(id=topic,lawId=law,title='Synthetic topic',order=i+1,requiredForV1=True) for law in sorted(r.LAWS) for i,topic in enumerate(required_topics[law])],'courses.json':dict(rulesVersion='rules-v1',ranks=ranks,levels=[dict(id=rank,title=rank,rankId=rank,prerequisiteIds=[] if i==0 else [ranks[i-1]],cardIds=[c['id'] for c in cards[:4]],questionIds=[q['id'] for q in questions[:10]],passRatio=0.8) for i,rank in enumerate(ranks)]),'aliases.json':[dict(kind='law',term='Synthetic '+law,pinyin=pinyin,initials=initials,lawId=law) for law,pinyin,initials in [('criminal','xingfa','xf'),('civil','minfadian','mfd'),('public_security','zhian','za')]],'migrations.json':[]})
        self.manifest=dict(schemaVersion=1,packageId='fixture-positive',createdAt=self.when,minReaderVersion=1,lawEditions=editions,files=[],releaseApprovalId='release')
        self.write()
    def tearDown(self): self.temp.cleanup()
    def approve(self,identifier,key,value,people):
        hashed=value if isinstance(value,str) else r.object_digest(value)
        roles={p['id']:p['roles'][0] for p in self.registry['reviewers']}
        self.approvals.append(dict(id=identifier,objectKey=key,objectDigest=hashed,decision='approved',reviews=[dict(reviewerId=p,role=roles[p],reviewedAt=self.when,objectDigest=hashed) for p in people],sampledObjectKeys=[],riskAssessment='Synthetic risk review',unsampledSummary='Synthetic remainder'))
    def write(self):
        self.manifest['files']=[]
        for name,value in sorted(self.docs.items()):
            data=r.canonical(value);path=self.package/name;path.parent.mkdir(exist_ok=True);path.write_bytes(data)
            self.manifest['files'].append(dict(path=name,sha256=r.digest(data),bytes=len(data)))
        self.approvals=[a for a in self.approvals if a['id']!='release']
        self.approve('release','package:'+self.manifest['packageId'],r.package_digest(self.manifest),['owner','lawyer'])
        self.approvals[-1]['sampledObjectKeys']=['card:'+self.docs['cards.json'][0]['id']]
        data=r.canonical(self.approvals);(self.package/'approvals.json').write_bytes(data)
        self.manifest['files'].append(dict(path='approvals.json',sha256=r.digest(data),bytes=len(data)))
        (self.package/'manifest.json').write_bytes(r.canonical(self.manifest))
    def validate(self): return r.validate(self.package,self.registry,self.sources,self.today)
    def test_structurally_valid_synthetic_bundle(self): self.validate()
    def test_modified_file_rejected(self):
        with (self.package/'cards.json').open('ab') as stream: stream.write(b' ')
        with self.assertRaisesRegex(r.Invalid,'SHA-256'):self.validate()
    def test_path_traversal_rejected(self):
        with self.assertRaises(r.Invalid):r.confined(self.package,'../outside.json')
        outside=self.root/'outside';outside.write_text('test');(self.package/'escape').symlink_to(outside)
        with self.assertRaises(r.Invalid):r.confined(self.package,'escape')
    def test_same_person_cannot_proofread_twice(self):
        self.approvals[0]['reviews'][1]['reviewerId']='p1';self.write()
        with self.assertRaisesRegex(r.Invalid,'independent'):self.validate()
    def test_stale_approval_after_card_edit(self):
        self.docs['cards.json'][0]['title']='Changed after review';self.write()
        with self.assertRaisesRegex(r.Invalid,'stale approval'):self.validate()
    def test_wrong_edition_rejected(self):
        self.docs['cards.json'][0]['articleRefs'][0]=dict(self.docs['cards.json'][0]['articleRefs'][0],editionId='other');self.write()
        with self.assertRaisesRegex(r.Invalid,'exact article reference'):self.validate()
    def test_missing_inventory_item_rejected(self):
        self.manifest['lawEditions'][0]['articleInventoryHash']=r.object_digest(['1','2']);self.write()
        with self.assertRaisesRegex(r.Invalid,'inventory'):self.validate()
    def test_unknown_reviewer_rejected(self):
        self.registry['reviewers']=[]
        with self.assertRaisesRegex(r.Invalid,'unauthorized reviewer'):self.validate()
    def test_stale_and_future_reviews_rejected(self):
        for value in ['2026-01-01','2027-01-01']:
            with self.subTest(value=value):
                with self.assertRaises(r.Invalid):r.reviewed(value,self.today,'fixture')
    def test_duplicate_json_keys_rejected(self):
        path=self.root/'duplicate.json';path.write_text('{"id":1,"id":2}')
        with self.assertRaisesRegex(r.Invalid,'duplicate JSON'):r.read(path)
    def test_compilation_is_deterministic_and_keeps_all_questions(self):
        from compile_bundle import compile_release
        first=self.root/'build-one';second=self.root/'build-two'
        compile_release(self.package,self.registry,self.sources,first,self.today)
        compile_release(self.package,self.registry,self.sources,second,self.today)
        self.assertEqual((first/'approved-catalog.json').read_bytes(),(second/'approved-catalog.json').read_bytes())
        catalog=r.read(first/'approved-catalog.json')
        self.assertEqual(len(catalog['questions']),300)
        self.assertEqual(len(catalog['cards'][0]['questionIds']),3)
        self.assertEqual(catalog['articles'][0]['text'],self.docs['laws/criminal-e1.json']['articles'][0]['originalText'])
    def test_build_gate_rejects_modified_generated_catalog(self):
        from compile_bundle import compile_release,verify_generated
        output=self.root/'generated';compile_release(self.package,self.registry,self.sources,output,self.today)
        with (output/'approved-catalog.json').open('ab') as stream:stream.write(b' ')
        with self.assertRaisesRegex(r.Invalid,'generated catalog'):
            verify_generated(output,self.registry,self.sources,self.today)
    def test_generator_does_not_replace_unrelated_files(self):
        from compile_bundle import compile_release
        output=self.root/'personal';output.mkdir();(output/'notes.txt').write_text('keep')
        with self.assertRaisesRegex(r.Invalid,'not owned'):
            compile_release(self.package,self.registry,self.sources,output,self.today)
        self.assertEqual((output/'notes.txt').read_text(),'keep')
    def test_altered_quote_rejected_even_after_structural_review_record_update(self):
        item=self.docs['interpretations.json'][0]
        item['consequences']=[dict(quote='不在原文中的处罚',articleRef=item['articleRefs'][0])]
        approval=next(a for a in self.approvals if a['id']==item['approvalId'])
        approval['objectDigest']=r.object_digest(item)
        for review in approval['reviews']:review['objectDigest']=approval['objectDigest']
        self.write()
        with self.assertRaisesRegex(r.Invalid,'altered consequence'):self.validate()
    def test_publisher_empty_fields_block_release(self):
        from release_gate import publisher_valid
        with self.assertRaises(r.Invalid):publisher_valid(dict(displayName='',supportEmail='',privacyPolicyURL=''))
    def test_required_topic_cannot_be_disabled(self):
        self.docs['topics.json'][0]['requiredForV1']=False;self.write()
        with self.assertRaisesRegex(r.Invalid,'mandatory V1 topic'):self.validate()
    def test_draft_schema_rejected(self):
        self.docs['cards.json'][0]['state']='draft';self.write()
        with self.assertRaisesRegex(r.Invalid,'approved'):self.validate()

    def test_unrelated_role_cannot_replace_second_proofreader(self):
        review=self.approvals[0]['reviews'][1]
        review.update(reviewerId='legal',role='legal_reviewer');self.write()
        with self.assertRaisesRegex(r.Invalid,'independent'):self.validate()

    def test_one_owner_lawyer_plus_unrelated_person_is_not_dual_review(self):
        self.registry['reviewers'].append(dict(id='both',active=True,roles=['lawyer','content_owner']))
        approval=self.approvals[-1]
        for review in approval['reviews']:review['reviewerId']='both'
        approval['reviews'].append(dict(reviewerId='legal',role='legal_reviewer',reviewedAt=self.when,objectDigest=approval['objectDigest']))
        data=r.canonical(self.approvals);(self.package/'approvals.json').write_bytes(data)
        record=next(f for f in self.manifest['files'] if f['path']=='approvals.json')
        record.update(bytes=len(data),sha256=r.digest(data))
        (self.package/'manifest.json').write_bytes(r.canonical(self.manifest))
        with self.assertRaisesRegex(r.Invalid,'independent'):self.validate()
