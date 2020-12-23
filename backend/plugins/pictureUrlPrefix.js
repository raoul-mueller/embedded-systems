const config = require('../config');

module.exports = (schema, options) => {
    schema.post(['save', 'find', 'findOne'], function(docs) {
        if (!Array.isArray(docs)) {
            docs = [docs];
        }
        for (const doc of docs) {
            if (doc && doc.pictureUrl) {
                doc.pictureUrl = `${config.staticUrl}/${doc.pictureUrl}`;
            }
        }
    });
}