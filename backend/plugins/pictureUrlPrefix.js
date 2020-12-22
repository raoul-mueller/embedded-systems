const config = require('../config');

module.exports = (schema, options) => {
    schema.post(['find', 'findOne'], function(docs) {
        if (!Array.isArray(docs)) {
            docs = [docs];
        }
        for (const doc of docs) {
            doc.pictureUrl = `${config.staticUrl}/${doc.pictureUrl}`;
        }
    });
}