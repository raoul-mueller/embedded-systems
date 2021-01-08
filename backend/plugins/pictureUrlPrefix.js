const config = require('../config');

module.exports = (schema, options) => {
    schema.pre('save', function (next) {
        this.pictureUrl = this.pictureUrl.replace(`${config.staticUrl}/`, '');
        next();
    });
    schema.post(['save', 'find', 'findOne', 'findOneAndUpdate'], function(docs) {
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