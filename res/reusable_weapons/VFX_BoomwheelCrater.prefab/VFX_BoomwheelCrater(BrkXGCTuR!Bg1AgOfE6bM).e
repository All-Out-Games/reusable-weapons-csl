13
9161165242370
473089675180945 1744302645252957900
{
  "name": "VFX_BoomwheelCrater",
  "local_enabled": true,
  "local_position": {

  },
  "local_rotation": 0,
  "local_scale": {
    "X": 1.5000000000000000,
    "Y": 1.5000000000000000
  }
},
{
  "cid": 1,
  "aoid": "473143790271407:1744302659521466100",
  "component_type": "Internal_Component",
  "internal_component_type": "Spine_Animator",
  "data": {
    "skeleton_data_asset": "anims/reusable-weapons/nuke_crater/MWSD116_smash_crater.spine",
    "ordered_skins": [
      "default"
    ],
    "depth_offset": 1
  }
},
{
  "cid": 3,
  "aoid": "171179841557759:1744825798397102800",
  "component_type": "Mono_Component",
  "mono_component_type": "LoopingVFX",
  "data": {
    "Lifetime": 15,
    "Skeleton": "473143790271407:1744302659521466100",
    "InitialAnimationName": "MWSD116/spawn",
    "LoopAnimationName": "MWSD116/idle",
    "OutroAnimationName": "MWSD116/despawn",
    "OutroAnimationTime": 0.6999999880790710
  }
}
