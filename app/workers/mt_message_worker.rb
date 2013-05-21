# this worker should not define .perform or @queue
# since it will be run by pace https://github.com/groupme/pace
# and the queue should be dynamically set
class MtMessageWorker
end
