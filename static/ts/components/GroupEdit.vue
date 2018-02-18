<template>
    <li class="list-group-item DataGroup" @mousedown="select" >

        <template v-if="isEdit">
            <DestructBtn cell="group"></DestructBtn>
            <input maxlength="20" class="DataLabel" v-model="group.name" placeholder="Name..."/>
        </template>
        <template v-else>
            <label class="DataLabel">{{ group.name }}&nbsp;</label>
        </template>


        <ul class="list-group">
            <template v-for="cell in group.expr">
                <template v-if="cell.type == 'group'">
                    <Cell-List :key="cell.id" v-bind:group="cell"></Cell-List>
                </template>
                <template v-else>
                    <Cell-Edit v-if="$store.state.editCell === cell" :key="cell.id" v-bind:cell="cell"></Cell-Edit>
                    <Cell-View v-else :key="cell.id" v-bind:cell="cell"></Cell-View>
                </template>
            </template>
            <!--<template v-if="onadd !== undefined">-->
                <!--<a class="list-group-item list-group-item-action AddItem" @mousedown="addNewCell">-->
                    <!--<i class="fas fa-plus"></i>-->
                    <!--Add Item-->
                    <!--</a>-->
            <!--</template>-->
        </ul>

        <div class="alert alert-danger CellError" role="alert" v-for="error in group.errors">
              <i class="fas fa-exclamation-triangle"></i> &nbsp; {{error}}
        </div>

    </li>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('CellList', {
    name: 'CellList',
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
