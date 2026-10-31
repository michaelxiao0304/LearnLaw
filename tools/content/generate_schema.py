#!/usr/bin/env python3
"""Single schema source; export Draft 2020-12 for editors and the release validator."""
import json
from pathlib import Path
S = {'type': 'string', 'minLength': 1}
ID = dict(S, pattern=r'^[A-Za-z0-9][A-Za-z0-9_.-]*$')
D = dict(S, format='date')
H = dict(S, pattern='^[0-9a-f]{64}$')
N = {'type': 'integer', 'minimum': 1}
def arr(item, minimum=1): return {'type': 'array', 'items': item, 'minItems': minimum}
def obj(fields, optional=()):
    return {'type': 'object', 'properties': fields, 'required': [k for k in fields if k not in optional], 'additionalProperties': False}
def ref(name): return {'$ref': '#/$defs/' + name}

def schema():
    defs = {}
    defs['articleRef'] = obj(dict(lawId=ID, lawVersionId=ID, editionId=ID, articleKey=dict(S, pattern=r'^[1-9][0-9]*(?:-[1-9][0-9]*)?$')))
    reviewed = dict(reviewedAt=D, approvalId=ID, state={'const':'approved'})
    defs['file'] = obj(dict(path=S, sha256=H, bytes={'type':'integer','minimum':0}))
    defs['edition'] = obj(dict(lawId={'enum':['criminal','civil','public_security']}, lawVersionId=ID, editionId=ID, name=S, promulgatedAt=D, effectiveAt=D, statusAtReview={'const':'effective'}, reviewedAt=D, sourceId=ID, articleCount=N, articleInventoryHash=H))
    defs['manifest'] = obj(dict(schemaVersion={'const':1}, packageId=ID, createdAt=D, minReaderVersion={'const':1}, lawEditions=arr(ref('edition')), files=arr(ref('file')), releaseApprovalId=ID))
    defs['source'] = obj(dict(id=ID, kind={'enum':['law','case','interpretation']}, publisher=S, title=S, url=S, publishedAt=D, retrievedAt=D, snapshotPath=S, snapshotHash=H), optional=('publishedAt',))
    defs['sources'] = arr(ref('source'))
    defs['article'] = obj(dict(articleKey=dict(S,pattern=r'^[1-9][0-9]*(?:-[1-9][0-9]*)?$'), displayNumber=S, chapterPath=arr(S,0), order=N, originalText=S, textHash=H, reviewedAt=D, sourceId=ID))
    defs['law'] = obj(dict(editionId=ID, articles=arr(ref('article'))))
    defs['point'] = obj(dict(text=S, articleRefs=arr(ref('articleRef'))))
    defs['quote'] = obj(dict(quote=S, articleRef=ref('articleRef')))
    defs['interpretation'] = obj(dict(id=ID, revision=N, points=arr(ref('point')), misconceptions=arr(ref('point')), consequences=arr(ref('quote'),0), articleRefs=arr(ref('articleRef')), **reviewed))
    defs['interpretations'] = arr(ref('interpretation'))
    defs['conclusion'] = obj(dict(category={'enum':['unlawful','possibly_unlawful','attention']}, text=S, qualifications=S))
    defs['story'] = obj(dict(kind={'enum':['official_case_adaptation','illustrative_scenario']}, text=dict(S,maxLength=300), adaptationNote=S))
    defs['card'] = obj(dict(id=ID, revision=N, primaryLawId=ID, topicIds=arr(ID), title=S, conclusion=ref('conclusion'), story=ref('story'), interpretationIds=arr(ID), articleRefs=arr(ref('articleRef')), sourceIds=arr(ID), quizIds=arr(ID), **reviewed))
    defs['cards'] = arr(ref('card'))
    defs['option'] = obj(dict(id=ID,text=S))
    defs['question'] = obj(dict(id=ID, revision=N, kind={'enum':['single_choice','true_false']}, prompt=S, options=arr(ref('option'),2), correctOptionIds={'type':'array','items':ID,'minItems':1,'maxItems':1}, explanation=S, cardIds=arr(ID), articleRefs=arr(ref('articleRef')), **reviewed))
    defs['questions'] = arr(ref('question'))
    defs['topic'] = obj(dict(id=ID,parentId=ID,lawId=ID,title=S,order=N,requiredForV1={'type':'boolean'}),optional=('parentId',))
    defs['topics'] = arr(ref('topic'))
    defs['level'] = obj(dict(id=ID,title=S,rankId={'enum':['bronze','silver','gold','master']},prerequisiteIds=arr(ID,0),cardIds=arr(ID),questionIds=arr(ID,10),passRatio={'const':0.8}))
    defs['courses'] = obj(dict(rulesVersion=ID,ranks={'const':['bronze','silver','gold','master']},levels=arr(ref('level'),4)))
    defs['alias'] = obj(dict(kind={'enum':['law','keyword']},term=S,pinyin=dict(S,pattern='^[a-z]+$'),initials=dict(S,pattern='^[a-z]+$'),lawId=ID))
    defs['aliases'] = arr(ref('alias'),0)
    defs['migration'] = obj(dict(kind={'enum':['article','card','question']},oldId=S,newIds=arr(S,0),change={'enum':['same','revised','removed']},reason=S))
    defs['migrations'] = arr(ref('migration'),0)
    defs['review'] = obj(dict(reviewerId=ID,role={'enum':['proofreader','legal_reviewer','lawyer','content_owner']},reviewedAt=D,objectDigest=H))
    defs['approval'] = obj(dict(id=ID,objectKey=S,objectDigest=H,decision={'const':'approved'},reviews=arr(ref('review')),sampledObjectKeys=arr(S,0),riskAssessment=S,unsampledSummary=S))
    defs['approvals'] = arr(ref('approval'))
    return {'$schema':'https://json-schema.org/draft/2020-12/schema', '$defs':defs}

if __name__ == '__main__':
    path=Path(__file__).resolve().parents[2]/'resource/content/schema/bundle.schema.json'
    path.write_text(json.dumps(schema(),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
