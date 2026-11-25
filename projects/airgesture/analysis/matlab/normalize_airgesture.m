function features = normalize_airgesture(points,width,height)
% Match landmark_features.py. points: 21x3 numeric [x y z], rows IDs 0..20.
% Output is 1x63 BEFORE stored model standardization.
validateattributes(points,{'numeric'},{'size',[21 3],'finite','real'});
validateattributes(width,{'numeric'},{'scalar','positive','finite'});
validateattributes(height,{'numeric'},{'scalar','positive','finite'});
points=single(points);
points(:,2)=points(:,2)*single(height/width);
points=points-points(1,:);
% Python IDs 5,9,13,17 correspond to MATLAB rows 6,10,14,18.
scale=mean(sqrt(sum(points([6 10 14 18],:).^2,2)));
if ~isfinite(scale)||scale<1e-6,error('Degenerate palm scale');end
points=points/scale;
% Transpose is necessary: MATLAB reshapes by columns, Python by rows.
features=reshape(points.',1,63);
end
