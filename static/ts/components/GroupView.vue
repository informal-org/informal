<template>
    <li class="list-group-item DataGroup">

        <template v-if="$store.state.editCell === group">
            <DestructBtn v-bind:cell="group"></DestructBtn>

            <input maxlength="20" class="DataLabel" v-model="group.name" placeholder="Name..."/>
        </template>
        <template v-else>
            <label class="DataLabel">{{ group.name }}&nbsp;</label>
        </template>

        <Cell-List v-bind:cells="group.expr"></Cell-List>

        <Cell-Errors v-bind:cell="group"></Cell-Errors>
    </li>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('GroupView', {
    name: 'GroupView',
    props: {
        'group': {type: Group},
    },
    methods: {
        addCell: function(event: Event) {
            // todo: Vuex this
            // let c = new Cell("", "test", this.cellgroup.env, "hello");
            // let c = this.cellgroup.env.createCell("", "", "")
            // this.cellgroup.addChild(c);
            // window.lastAddedIndex = this.cellgroup.env.all_cells.indexOf(c);
        },
    },
});
</script>

<style>
</style>
