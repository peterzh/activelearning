classdef act
    properties
        dw = 0.1;
        w_range = [-1 1]*20;
        prior_mean = [0 0];
        prior_cov = eye(2)*15;
    end
    
    properties (Access=private)
        w0;
        w1;
    end
    
    methods
        function obj = act
            obj.w0 = obj.w_range(1) : obj.dw : obj.w_range(2);
            obj.w1 = obj.w_range(1) : obj.dw : obj.w_range(2);
        end
       
        function l = likelihood(obj,data)
            stim = data.stim; %must be column vector
            resp = data.resp; %must be column vector
%             
             %Original method
%             l = nan(numel(obj.w0),numel(obj.w1));
%             for w0idx = 1:numel(obj.w0)
%                 for w1idx = 1:numel(obj.w1)
%                     w = [obj.w0(w0idx) obj.w1(w1idx)];
%                     z = w(1) + w(2)*stim;
%                     pGO = 1./(1+exp(-z));
%                     lik = pGO.*(resp==1) + (1-pGO).*(resp==0);
%                     l(w0idx,w1idx) = prod(lik);
%                 end
%             end

%             %Slightly faster method which tries to do this all in one go!
%             [W1,W0] = meshgrid(obj.w1,obj.w0);
%             Z = bsxfun(@times,W1,permute(stim,[3 2 1]));
%             Z = bsxfun(@plus,W0,Z);
%             pGO = 1./(1+exp(-Z));
%             l = bsxfun(@times,pGO,permute(resp==1,[3 2 1])) + bsxfun(@times,(1-pGO),permute(resp==0,[3 2 1]));
%             l = prod(l,3);
            
%             %Fastest method (so far) which calculates the entire W matrix for each trial
            numTrials = length(stim);
            [W1,W0] = meshgrid(obj.w1,obj.w0);
            l = nan(numel(obj.w0),numel(obj.w1),numTrials);
            for t = 1:numTrials
                pGO = 1./(1+exp(-(W0 + W1*stim(t))));
                l(:,:,t) = pGO*resp(t) + (1-pGO)*(1-resp(t));
            end
            l = prod(l,3);
        end
        
        function p = prior(obj)
            %prior on w is a 2D normal dist with mean 0 and spherical
            %covariance
            [W1,W0] = meshgrid(obj.w1,obj.w0);
            p = mvnpdf([W0(:) W1(:)],obj.prior_mean,obj.prior_cov);
            p = reshape(p,size(W0));
            p = p/sum(p(:)*obj.dw^2); %renormalise if truncated
        end
        
        function p = posterior(obj,data)
            
            if isempty(data.stim)
                p = obj.prior;
            else
                pr = obj.prior;
                lik = obj.likelihood(data);      
                prlik = pr.*lik;
                p = prlik/sum(prlik(:)*obj.dw^2);
            end
            
        end
                        
        function plotfcn(obj,which,data)
            
            switch(which)
                case 'prior'
                    dist = obj.prior;
                case 'likelihood'
                    dist = obj.likelihood(data);
                case 'posterior'
                    dist = obj.posterior(data);
            end
                        
            [~,i]=max(dist(:)); %index of maximum value of distribution
            [row,col]=ind2sub([numel(obj.w0) numel(obj.w1)],i);
            
            imagesc(obj.w0,obj.w1,dist); set(gca,'ydir','normal'); 
            xlabel('W1'); ylabel('W0');
            title([which ' w0_{max}=' num2str(obj.w0(row)) ' w1_{max}=' num2str(obj.w1(col)) ]);
        end
        
        function simulate(obj,trueW0,trueW1)
            d1.stim = -1 + 2*rand(100,1);
            d1.resp = binornd(1,1./(1+exp(-(trueW0 + trueW1*d1.stim))));
            
            obj.fit(d1);
        end
        
        function fit(obj,d1) %Try this on fake data
            %Generate fake dataset
            figure;
            subplot(2,3,1);
            obj.plotfcn('prior',d1); 
            
            subplot(2,3,2);
            obj.plotfcn('likelihood',d1); 
            
            subplot(2,3,3);
            obj.plotfcn('posterior',d1);
            
            subplot(2,1,2);
            post = obj.posterior(d1);
            plot(-5:.1:5,obj.predict(-5:.1:5,post));
            hold on;
            plot(d1.stim,d1.resp,'o');
            set(gcf,'color','w');
        end
        
        function py = predict(obj,newX,posterior)
            %Integrate over all w in the posterior to calculate the
            %prediction
            [W1,W0] = meshgrid(obj.w1,obj.w0);

            py=[];
            for xn = 1:length(newX)
                phat = obj.dw * obj.dw * posterior./(1+exp(-(W0 + W1*newX(xn))));
                py(xn) = sum(phat(:));
            end            
        end
        
        function h = diffentropy(obj,xn1_list,data)
            %Entropy contains yn+1 but we don't know the value so let's take
            %expectation of the entropy over all possible yn+1
            old_post = obj.posterior(data);
                        
            for xn1 = 1:length(xn1_list)                
                ch = []; py = [];
                for yn1 = [1 0]
                    
                    %calculate new posterior by iterating 1 new datapoint from the old
                    %posterior                    
                    d2.stim = xn1_list(xn1);
                    d2.resp = yn1;
                    lik = obj.likelihood(d2);
                    new_post = old_post.*lik;
                    new_post = new_post/(sum(new_post(:))*obj.dw^2);
                    
                    %calculate predictive dist
                    p = obj.predict(xn1_list(xn1),old_post);
                    if yn1==0
                        p = 1-p;
                    end
                    py = [py; p];
                    
                    ent = -new_post.*log(new_post)*obj.dw^2;
                    ch = [ch; nansum(ent(:))];
                end
                
                h(xn1) = ch'*py;
            end
        end
        
        function runactive(obj)
            %Start with initially small data-set and keep adding new
            %stimuli, checking that the entropy is decreasing over this
            %process
            warning('Only works up to about 1000 trials due to numerical instability');
            
            f = figure;
            s1 = subplot(3,1,1);
            s2 = subplot(3,1,2);
            s3 = subplot(3,1,3);
                        
            postEnt = []; 
            
            methods = {'random','activelearning'};
            
            stim = cell(1,length(methods));
            resp = cell(1,length(methods));
            
            xn1_test = linspace(-1,1,40);
            for i = 1:1200
                %Try out a whole bunch of heuristics for selecting
                %xn+1, and assess how the posterior entropy decreases over
                %time
                       
%                 xn1_test = -1 + 2*rand(1,40);                                            
                for m = 1:length(methods)
                    xn1 = obj.getnext(methods{m},xn1_test,stim{m},resp{m});
                    
                    stim{m} = [stim{m}; xn1];
                    resp{m} = [resp{m}; binornd(1,1./(1+exp(-(0 + 7*xn1))))];
                    
                    %Measure differential entropy of the new posterior
                    newPost = obj.posterior(struct('stim',stim{m},'resp',resp{m}));
                    newPostEntVal = -nansum(nansum(newPost.*log(newPost)))*obj.dw^2;
                    postEnt(i,m) = newPostEntVal;
                end


                imagesc(s1,obj.w0,obj.w1,newPost);
                plot(s2,postEnt); xlabel('Iter'); ylabel('Posterior differential entropy');
                hist(s3,stim{2}); 
                drawnow;
                
                %Rescale W range by the range of the current posterior
                w1_marginal = sum(newPost,1);
                w0_marginal = sum(newPost,2);
                if w1_marginal(1) <0.00001
                    obj.w1(1) = [];
                end
                
                if w1_marginal(end) <0.00001
                    obj.w1(end) = [];
                end
                
                if w0_marginal(1) <0.00001
                    obj.w0(1) = [];
                end
                
                if w0_marginal(end) <0.00001
                    obj.w0(end) = [];
                end
                
                if numel(newPost) <1000
                    obj.dw = obj.dw/2;
                    obj.w1 = obj.w1(1) : obj.dw : obj.w1(end);
                    obj.w0 = obj.w0(1) : obj.dw : obj.w0(end);
                end
                
            end
        end
        
        function best_xn1 = getnext(obj,method,xn1_test,old_stim,old_resp)
            switch(method)
                case 'activelearning' %Uses active learning to select xn+1
                    d1.stim = old_stim;
                    d1.resp = old_resp;
                    
                    %Function takes the current dataset (can be empty struct)
                    diffE = obj.diffentropy(xn1_test,d1);
                    [~,idx] = min(diffE);
                    best_xn1 = xn1_test(idx);
                case 'random' %Just selects at random from the candidates
                    best_xn1 = randsample(xn1_test,1);
                case '0'
                    best_xn1 = 0;
            
            end
        end
    end
    
    
    
end