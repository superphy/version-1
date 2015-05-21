var Poller;

Poller = (function() {
    function Poller(jobId, alertStatusDiv) {
        this.jobId = jobId;
        this.alertStatusDiv = alertStatusDiv;
        if (this.jobId == null) {
            throw new SuperphyError('Job id must be specified in Poller constructor');
        }
        if (this.alertStatusDiv == null) {
            throw new SuperphyError('Need to specify status div for Poller constructor');
        }
    }

    Poller.prototype.pollJob = function() {
        that = this;
        that.alertStatusDiv.parent().collapse('hide');
        jQuery.ajax({
            type: 'POST',
            url: '/groups/poll',
            data: {
                'job_id': this.jobId
            }
        }).done(function(data) {
            var status = JSON.parse(data);
            that.alertStatusDiv.empty();
            var loader = $('<div class="loader-job"><span></span></div>');
            that.alertStatusDiv.append(loader);
            that.alertStatusDiv.parent().collapse('show');
            setTimeout(function() {
                that.alertStatusDiv.empty();
                if (status.error) {
                    $('<p>Error: '+status.error+'</p>').hide().appendTo(that.alertStatusDiv).fadeIn(500);
                }
                else {  
                    $('<p>'+status.status+'</p>').hide().appendTo(that.alertStatusDiv).fadeIn(500);
                }
            }, 2000);
            if (status.error) { 
                return false;
            }
            else {
                setTimeout(function(){that.pollJob()}, 10000);  
            }
        });
        return true;
    };

    return Poller;

})();
