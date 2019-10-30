import json
from deoplete.source.base import Base

# @see https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
COMPLETION_ITEM_KIND = [
    'Text',
    'Method',
    'Function',
    'Constructor',
    'Field',
    'Variable',
    'Class',
    'Interface',
    'Module',
    'Property',
    'Unit',
    'Value',
    'Enum',
    'Keyword',
    'Snippet',
    'Color',
    'File',
    'Reference',
    'Folder',
    'EnumMember',
    'Constant',
    'Struct',
    'Event',
    'Operator',
    'TypeParameter',
]

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'lamp'
        self.mark = '[LAMP]'
        self.rank = 500
        self.input_pattern = r'[^\w\s]$'
        self.min_pattern_length = 0
        self.is_volatile = True
        self.sorters = []
        self.vars = {}
        self.id = 0

    def gather_candidates(self, context):
        request = self.vim.call('deoplete_lamp#find_request')
        if request:
            if request['responses']:
                return self.to_candidates(request)
            return []
        else:
            self.vim.call('deoplete_lamp#request')
        return []

    def to_candidates(self, request):
        candidates = []

        for response in request['responses']:
            items = sorted(response['items'], key=lambda x: x.get('sortText', x['label']))
            for item in items:
                self.id += 1
                candidates.append({
                    'word': item['insertText'] if item.get('insertText', None) else item['label'],
                    'abbr': item['label'],
                    'kind': COMPLETION_ITEM_KIND[item['kind'] - 1 if 'kind' in item else 0],
                    'user_data': json.dumps({
                        'lamp': {
                            'id': self.id,
                            'server_name': response['server_name'],
                            'completion_item': item
                        }
                    })
                })
        return candidates

